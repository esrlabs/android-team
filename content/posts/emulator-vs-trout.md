---
title: "Virtual devices: Emulator vs Trout"
draft: false
author: "Suraj Chavan"
---

In Android development, building reliable apps and platforms requires efficient tools and environment. Instead of relying solely on physical hardware, developers can use virtual environments like the AOSP Emulator or AAOS Trout for development and testing, choosing the platform that best fits their specific use case. Virtual devices provide additional flexibility and speed for experimentation.  

The Android Emulator is widely used by app developers for testing and development. AAOS Trout, on the other hand, is an automotive-focused extension of Cuttlefish, designed specifically for Android Automotive OS (AAOS) and running as a guest VM on a hypervisor to provide a production-like environment for automotive engineers.

Understanding the differences between these two virtual environments - helps developers and engineers choose the right environment for their projects.

   

| **Emulator** | **Trout** |
|----------|-------|
| Ideal for application development and testing | Supports application development and testing |  
| Not reliable for platform development and testing | Supports platform development and testing |   
| Almost all the interactions done at HALs or OS level are mocked. Thus, emulator is not reliable to work on related modules | Some of the HALs are implemented using virtualization which indirectly interacts with the real physical Hardware on the host side. Refer [AAOS Trout](https://source.android.com/docs/automotive/virtualization/reference_platform) |
| Mainly designed for local executions  | Supports local execution  |
| Not reliable for execution on remote servers or CI environments | Ideal for executions on the remote servers or CI environments |
| Abstracts hardware behavior for efficiency, which can diverge from real hardware characteristics  |  Trout uses VM-level virtualization, making it much closer to real hardware behavior than a lightweight emulator  |
| Low isolation between the guest OS and the host machine | Strong isolation between the guest OS and the host machine |
| Less secure as compared to Trout  | More secure |
| Works on Linux, MacOS and Windows  |  Only works on Linux  |
| Depends on QEMU; cannot run without it | Hypervisor-agnostic; can run on QEMU, crosvm etc |