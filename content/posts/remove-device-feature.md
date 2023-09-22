---
title: "How To Remove A Device Feature"
date: 2023-08-07T13:12:43+02:00
draft: false
author: "Florian Bramer"
---

Recently, I had to remove a couple of device features from an Android 12 build.

Some reasons why we wanted to remove them:

- they were actually not supported by our device
- we didn't want to expose them to the user
- they were causing unnecessary CTS failures

In this post, I want to guide you through the steps I took to trim down the list of declared device features.

### What are Device Features?

Any android devices declares a list of device features it supports. For example, in the early years of Android, there where phones with and without a built in compass sensor.

Imagine you are an app developer working on a compass app and you want to assure that your app only gets installed on phones with compass sensor.

You could archive that by declaring a dependency onto the corresponding device feature in your `AndroidManifest.xml`:

```
<manifest ... >
    <uses-feature android:name="android.hardware.sensor.compass"
                  android:required="true" />
    ...
</manifest>
```

See https://developer.android.com/guide/topics/manifest/uses-feature-element#features-reference for a list of device features.

### Inspecting all exposed Device Features

First let's inspect all the device features our device declares. One can do that by using an `adb shell` session and Android's package manager.

```
> pm list features
feature:android.hardware.audio.output
feature:android.hardware.bluetooth
feature:android.hardware.bluetooth_le
feature:android.hardware.broadcastradio
feature:android.hardware.camera.any
feature:android.hardware.camera.autofocus
feature:android.hardware.ethernet
feature:android.hardware.faketouch
feature:android.hardware.location
feature:android.hardware.location.gps
feature:android.hardware.location.network
...
<many more>
...
```

Let's take a deeper look how this list is assembled.

The package manager calculates the list from the .xml files it can find in the these folders

- vendor/etc/permissions
- system/etc/permissions
- system_ext/etc/permissions

during startup. For example at

_vendor/etc/permissions/android.hardware.bluetooth_le.xml_

we can find the file which declares the `android.hardware.bluetooth_le` device feature we saw in the list above:

```
<?xml version="1.0" encoding="utf-8"?>
<!-- Copyright (C) 2013 The Android Open Source Project

     Licensed under the Apache License, Version 2.0 (the "License");
     you may not use this file except in compliance with the License.
     You may obtain a copy of the License at

          http://www.apache.org/licenses/LICENSE-2.0

     Unless required by applicable law or agreed to in writing, software
     distributed under the License is distributed on an "AS IS" BASIS,
     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
     See the License for the specific language governing permissions and
     limitations under the License.
-->
<!-- Adds the feature indicating support for the Bluetooth Low Energy API -->
<permissions>
    <feature name="android.hardware.bluetooth_le" />
</permissions>
```

### Removing individual Device Features

Now let's imagine we would like to remove `android.hardware.bluetooth_le` from the list of declared device features. An obvious way to do that, would be to find the _android.hardware.bluetooth_le.xml_ file in our source tree and remove (or comment out) the line which defines the feature:

_frameworks/native/data/etc/android.hardware.bluetooth_le.xml_:
```
<permissions>
<!--
    Purposly commented out because we don't want to support BT Low Energy on our device
    <feature name="android.hardware.bluetooth_le" />
-->
</permissions>
```

But this solution comes with a couple of drawbacks:
- By AOSP convention, individual device configurations should go into the _device/_ folder. Your co-workers might not find this change if you place it underneath _frameworks/native_
- Once a new Android version gets introduced into the project, your change might get overwritten

A more sustainable way to trim the list of device features would be to introduce a new .xml file in the device folder of your device.

e.g. _unavailable-features.xml_:

```
<?xml version="1.0" encoding="utf-8"?>

<permissions>
    <!-- we don't want to support BT Low Energy on our device -->
    <unavailable-feature name="android.hardware.bluetooth_le" />
</permissions>
```

All you need to do then is to copy the .xml during built time onto the vendor partition in one of your .mk files:

```
PRODUCT_COPY_FILES += device/<vendor>/<device>/unavailable-features.xml:vendor/etc/permissions/unavailable-features.xml
```

Afterwards the package manager will include your .xml into his calculations and `android.hardware.bluetooth_le` will disappear from the list of declared device features.