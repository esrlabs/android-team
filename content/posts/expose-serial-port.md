---
title: "How to expose a serial port to a custom AOSP running in Trout / Cuttlefish"
date: 2024-09-20T16:34:36+02:00
draft: false
author: "Danil Garmanov"
---

Android running in a virtualized environment normally has no access to the hardware of the host machine, most of the hardware it "works" with is instead emulated.

But sometimes one wants a way to attach external hardware to their custom Android without working with an actual physical Android device with a USB port.
In our case we needed to attach a serial device.

In this article we will demonstrate how one can expose a *serial port* to Trout.

# crosvm
Trout is based on [crosvm](https://github.com/google/crosvm), and crosvm already supports serial devices exposure using the `--serial` parameter of the `crosvm run` command.

But we use crosvm indirectly, through Trout, when we start it using the `launch_cvd` command.
And `launch_cvd` does not provide a way to pass values to the `--serial` param of `crosvm run`.

So we will add it.

# Modifying the source code of your AOSP fork
*Disclaimer: the diffs are shown for Android 14, diffs for other versions of Android would be slightly different.*

First, `cd device/google/cuttlefish`.

Now, let's add new Cuttlefish config parameter, in the header file:
```
diff --git a/host/libs/config/cuttlefish_config.h b/host/libs/config/cuttlefish_config.h
index 9a2af86cd..7c9bb5725 100644
--- a/host/libs/config/cuttlefish_config.h
+++ b/host/libs/config/cuttlefish_config.h
@@ -125,6 +125,9 @@ class CuttlefishConfig {
   void set_gem5_debug_flags(const std::string& gem5_debug_flags);
   std::string gem5_debug_flags() const;
 
+  void set_attach_serial_device(const std::string& attach_serial_device);
+  std::string attach_serial_device() const;
+
   void set_enable_host_uwb(bool enable_host_uwb);
   bool enable_host_uwb() const;
 
```
...and in the implementation file:
```
diff --git a/host/libs/config/cuttlefish_config.cpp b/host/libs/config/cuttlefish_config.cpp
index 5c9e8dc36..2bdf2d6e4 100644
--- a/host/libs/config/cuttlefish_config.cpp
+++ b/host/libs/config/cuttlefish_config.cpp
@@ -188,6 +188,15 @@ void CuttlefishConfig::set_gem5_debug_flags(const std::string& gem5_debug_flags)
   (*dictionary_)[kGem5DebugFlags] = gem5_debug_flags;
 }
 
+static constexpr char kAttachSerialDevice[] = "attach_serial_device";
+void CuttlefishConfig::set_attach_serial_device(
+    const std::string& attach_serial_device) {
+  (*dictionary_)[kAttachSerialDevice] = attach_serial_device;
+}
+std::string CuttlefishConfig::attach_serial_device() const {
+  return (*dictionary_)[kAttachSerialDevice].asString();
+}
+
 static constexpr char kWebRTCCertsDir[] = "webrtc_certs_dir";
 void CuttlefishConfig::set_webrtc_certs_dir(const std::string& certs_dir) {
   (*dictionary_)[kWebRTCCertsDir] = certs_dir;
```

Now let's add a new parameter to the `launch_cvd` command that would use this config change:
```
diff --git a/host/commands/assemble_cvd/flags.cc b/host/commands/assemble_cvd/flags.cc
index c5ef0344a..e10615d72 100644
--- a/host/commands/assemble_cvd/flags.cc
+++ b/host/commands/assemble_cvd/flags.cc
@@ -202,6 +202,16 @@ DEFINE_string(
     seccomp_policy_dir, CF_DEFAULTS_SECCOMP_POLICY_DIR,
     "With sandbox'ed crosvm, overrieds the security comp policy directory");
 
+DEFINE_string(
+    attach_serial_device, "",
+    "Path to a serial device that should be attached to crosvm "
+    "(/dev/<something>). "
+    "QEMU is not supported.\n"
+    "To see the attached device name inside the guest machine, look for a "
+    "corresponding log "
+    "message with the 'SERIAL_PORT' prefix during the VM start.\n"
+    "The device name is stable, but it may change on AOSP updates.");
+
 DEFINE_vec(start_webrtc, cuttlefish::BoolToString(CF_DEFAULTS_START_WEBRTC),
             "Whether to start the webrtc process.");
 
@@ -818,6 +828,8 @@ Result<CuttlefishConfig> InitializeCuttlefishConfiguration(
 
   tmp_config_obj.set_gem5_debug_flags(FLAGS_gem5_debug_flags);
 
+  tmp_config_obj.set_attach_serial_device(FLAGS_attach_serial_device);
+
   // streaming, webrtc setup
   tmp_config_obj.set_webrtc_certs_dir(FLAGS_webrtc_certs_dir);
   tmp_config_obj.set_sig_server_secure(FLAGS_webrtc_sig_server_secure);
```

Cuttlefish has already quite a few defined serial ports, let's increase their number by one:
```
diff --git a/host/libs/vm_manager/vm_manager.h b/host/libs/vm_manager/vm_manager.h
index 4b116bfd9..036a2d3eb 100644
--- a/host/libs/vm_manager/vm_manager.h
+++ b/host/libs/vm_manager/vm_manager.h
@@ -54,7 +54,8 @@ class VmManager {
   // - /dev/hvc9 = uwb
   // - /dev/hvc10 = oemlock
   // - /dev/hvc11 = keymint
-  static const int kDefaultNumHvcs = 12;
+  static const int kDefaultNumHvcs =
+    13; // NOTE: on merge conflicts do +1 to the upstream's value
 
   // This is the number of virtual disks (block devices) that should be
   // configured by the VmManager. Related to the description above regarding
```

And finally let's actually forward the new parameter to `crosvm`:
```
diff --git a/host/libs/vm_manager/crosvm_manager.cpp b/host/libs/vm_manager/crosvm_manager.cpp
index 100b71e56..d81b5eb08 100644
--- a/host/libs/vm_manager/crosvm_manager.cpp
+++ b/host/libs/vm_manager/crosvm_manager.cpp
@@ -449,6 +449,18 @@ Result<std::vector<MonitorCommand>> CrosvmManager::StartCommands(
   for (auto i = 0; i < VmManager::kMaxDisks - disk_num; i++) {
     crosvm_cmd.AddHvcSink();
   }
+
+  if (!config.attach_serial_device().empty()) {
+    crosvm_cmd.AddHvcReadWrite(config.attach_serial_device(),
+                               config.attach_serial_device());
+    LOG(INFO) << "SERIAL_PORT: attaching serial port to crosvm: "
+              << config.attach_serial_device()
+              << ", most likely device name inside the guest machine: /dev/hvc"
+              << crosvm_cmd.HvcNum() - 1;
+  } else {
+    crosvm_cmd.AddHvcSink();
+  }
+
   CF_EXPECT(crosvm_cmd.HvcNum() + disk_num ==
                 VmManager::kMaxDisks + VmManager::kDefaultNumHvcs,
             "HVC count (" << crosvm_cmd.HvcNum() << ") + disk count ("
```

... but not to QEMU, which is mostly used as AVD for normal (phone) Android apps (it might actually work, but we haven't test it since our focus is Trout / crossvm):
```
diff --git a/host/libs/vm_manager/qemu_manager.cpp b/host/libs/vm_manager/qemu_manager.cpp
index a2744a35d..a0ae1286b 100644
--- a/host/libs/vm_manager/qemu_manager.cpp
+++ b/host/libs/vm_manager/qemu_manager.cpp
@@ -556,6 +556,8 @@ Result<std::vector<MonitorCommand>> QemuManager::StartCommands(
     add_hvc_sink();
   }
 
+  add_hvc_sink();  // attach_serial_device, not supported on QEMU
+
   CF_EXPECT(
       hvc_num + disk_num == VmManager::kMaxDisks + VmManager::kDefaultNumHvcs,
       "HVC count (" << hvc_num << ") + disk count (" << disk_num << ") "
```

And the last thing we need to do is setting up proper access rights:
```
diff --git a/shared/config/ueventd.rc b/shared/config/ueventd.rc
index c604e3d23..dd7da4de3 100644
--- a/shared/config/ueventd.rc
+++ b/shared/config/ueventd.rc
@@ -44,5 +44,13 @@
 # keymint / Rust
 /dev/hvc11 0666 system system
 
+# Serial Port integration for the -attach_serial_device
+# param of the launch_cvd command.
+# Please update this name "/dev/hvcN" to "/dev/hvc{N+M}"
+# when kDefaultNumHvcs in 'host/libs/vm_manager/vm_manager.h' is updated.
+# The 'M' value here would be the delta between the new and the old values
+# of kDefaultNumHvcs.
+/dev/hvc12 0666 system system
+
 # Factory Reset Protection
 /dev/block/by-name/frp 0660 system system
```

You can find the full diff as one file [here](./full.diff).

# Conclusion
And that was basically it - now you can use the exposed port (`/dev/hvc12` in the case of the diff above) from inside of Android.
Don't forget to use the new parameter when running `launch_cvd`, e.g.:
```
launch_cvd ... -attach_serial_device /dev/ttyACM0
```
Replace `/dev/ttyACM0` with the actual path of the serial device on your host machine.

You can do a quick test by cross-compiling and adb-pushing a small binary to Android, which would attach to the serial port, and then executing the binary under `su`. Or just connect to the port from any system service.
