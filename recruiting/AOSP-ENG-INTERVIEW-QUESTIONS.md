# ASOP engineer interview questions

* Which java virtual machine is used in AOSP? What is so about it?
    * Dalvik on older versions, ART on newer versions
    * Followup questions. How does new process is started via zygote

* Could you please briefly describe AOSP source folder structure?
    * Follow-up: what is the difference between device and vendor folders

* How would you describe the purpose of vendor and product partitions? What is the difference between the two?

* How would you describe a process of adding a new device? Where would be the place to go to do that? What possible definitions/customizations could be done there? What is a “must” in order to define a new device?
    * Here I would expect to hear a little bit about /device structure, about product inheritance, make file inclusions, defining lunch target

* Could you please describe the Android boot process? What kind of boot steps are there? What kind of customizations are possible?
    * Here I’m after init (from Google), boot phases (like on-post-fs, on-early-init, etc), that it is possible to trigger on property or do smth during on-smth-phase

* How does adb work? Could you please describe very high level architecture or it?
    * Very briefly that it is client-server architecture, there is adbd on device side and client on… well, on the other side

* Which utilities would you use to interact with an Android device for development, debugging and flashing?
    * adb, logcat, fastboot, etc...

* How do framework services communicate with each other? How does IPC work in Android?
    * Here I’m after binder, hidl, aidl, intents and all that jazz. Not sure though, what would be the right way to ask about it.
    * Followup: what was the point of inventing the binder? -> security token passing, speed, blablabla

* General AOSP architecture? Very briefly and high level
    * Here I’m after smth like: kernel + drivers -> HALs + native services -> java framework + services -> app layer

* What is the role of system_server? On which level does it reside?
    * Who knows…. I would like to know as well…

* How does Android enforce and leverages security related concerns? Name a few mechanisms used?
    * Vanilla Linux DAC, framework permission system, SE Linux
    *Then we could potentially talk a little bit about each one of those. E.g. what are limitations of DAC and how SE Linux helps with that? Which type of permissions Android framework provided and what vendors and OEMs could do in order to provide permissions for shipped apps.

* Threads vs processes. Followup questions about concurrency: deadlock, race conditions, memory leak
