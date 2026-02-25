---
title: "Android 15 testing issues: signature permissions on user builds"
date: 2026-02-24T16:19:07+01:00
draft: false
author: "Ciprian Talaba"
---
After migrating our AOSP code base to Android 15 we started to have some issues while running our tests on user builds. Unfortunately this was discovered quite late since we initialled tested on user-debug builds, so another topic for the lessons-learned call. Some of the instrumentation tests were failing and the logs showed they were missing a permission. The suprise came from the fact that the tests were signed with the same key as the platform, and the permission was a signature permission, so the expectation was that everything will work, just as it did for Android 14 and older builds.

We noticed some logs like:
```
Signature permission android.permission.INTERACT_ACROSS_USERS_FULL for package ... not in signature permission allowlist
```
so we started to investigate based on that. This code seems to be part of the newly refactored PermissionService defined in: [frameworks/base/services/permission/java/.../access/permission/](https://cs.android.com/android/platform/superproject/main/+/main:frameworks/base/services/permission/java/com/android/server/permission/access/permission/).

### Why do we see this now?

The interesting code added in Android 15 is in [AppIdPermissionPolicy.kt](https://cs.android.com/android/platform/superproject/main/+/main:frameworks/base/services/permission/java/com/android/server/permission/access/permission/AppIdPermissionPolicy.kt;l=1207), method MutateStateScope.shouldGrantPermissionBySignature():

```
1200          if (!Flags.signaturePermissionAllowlistEnabled()) {
1201              return hasCommonSigner
1202          }
1203          if (!hasCommonSigner) {
1204              return false
1205          }
1206          // A platform signature permission also needs to be allowlisted on non-debuggable builds.
1207          if (permission.packageName == PLATFORM_PACKAGE_NAME) {
1208              val isRequestedByFactoryApp =
1209                  if (packageState.isSystem) {
1210                      // For updated system applications, a signature permission still needs to be
1211                      // allowlisted if it wasn't requested by the original application.
1212                      if (packageState.isUpdatedSystemApp) {
1213                          val disabledSystemPackage =
1214                              newState.externalState.disabledSystemPackageStates[
1215                                      packageState.packageName]
1216                                  ?.androidPackage
1217                          disabledSystemPackage != null &&
1218                              permission.name in disabledSystemPackage.requestedPermissions
1219                      } else {
1220                          true
1221                      }
1222                  } else {
1223                      false
1224                  }
1225              if (
1226                  !(isRequestedByFactoryApp ||
1227                      getSignaturePermissionAllowlistState(packageState, permission.name) == true)
1228              ) {
1229                  Slog.w(
1230                      LOG_TAG,
1231                      "Signature permission ${permission.name} for package" +
1232                          " ${packageState.packageName} (${packageState.path}) not in" +
1233                          " signature permission allowlist"
1234                  )
1235                  if (!Build.isDebuggable() || isSignaturePermissionAllowlistForceEnforced) {
1236                      return false
1237                  }
1238              }
1239          }
1240          return true
```

We can see that in case of requesting a platform permission (from android.* package) there are some new checks (line 1207), and there is a new check specific for user builds on line 1235 that will return false, and this is what was happening in our case. Searching the docs lead us to the official information from Google, mentioning the [allow-list mechanism for signature permissions](https://source.android.com/docs/core/permissions/signature-permission-allowlist).

This will work nice for components that are part of the production build, but our issues were happening in the tests, which are built separately from the production build, and executed using tradefed, just like CTS tests. In this case using the allow list mechanism will mean that the production build will contain something related to packages that are not installed by default, opening the platform to a potential breach. We tested this mechanism and it works as documented, but we didn't stop there since we expected that CTS is doing some magic to get these kind of permissions granted even if the tests are not signed with the platform key.

### Is tradefed doing some magic?

We identified some CTS tests that are using one of the permissions that we also see in the our issues logs, package android.car.cts built as CtsCarTestCases.apk, [cts/tests/tests/car/AndroidManifest.xml](https://cs.android.com/android/platform/superproject/main/+/main:cts/tests/tests/car/AndroidManifest.xml;l=28):

```
<uses-permission android:name="android.permission.INTERACT_ACROSS_USERS_FULL" />
```
 
Manually installing the package and running the tests show some failures, but no permission exceptions on the emulator:

```
adb install -r -g  CtsCarTestCases.apk
adb shell am instrument -w android.car.cts/androidx.test.runner.AndroidJUnitRunner
```

What we noticed is that when we install and run the Android 14 apk with the same package we are seeing permission exceptions, so either they updated the tests not to need the permission anymore (although is listed in the manifest), or they did something else on the tests side.

There does not seem to be anything on the tradefed side that is doing some magic for CTS tests.

### Next step: investigate the CTS tests source code

We started to look into one of the initial exceptions that we saw while trying to run the A14 tests and I see some interesting changes in A15 code, the test has been modified with this change:

https://cs.android.com/android/_/android/platform/cts/+/f321adbd2d44853053bec5b6041374b5f962fdce...4beface53ae3d634993b427d1c5e9a201faf58da

Seems like there is a mechanism to be granted these permissions temporary for the shell identity (which is used for running tests): https://developer.android.com/reference/android/app/UiAutomation#adoptShellPermissionIdentity(java.lang.String[])

```
mUiAutomation.adoptShellPermissionIdentity(String... permissions)
```

We did some testing with one of our components after reverting the allow list changes that we did and the results were good. We just added this for one test in the setup(), and it seems to apply for all the next tests as well, so it should be sufficient to add it to one test. But if we want to be able to always run individual tests without permissions issues we will of course need to add this code into each test that needs some signature permissions.

Also there seem to be a pair to the adoptShellPermissionIdentity() that will drop all these permissions, which is recommended if you want to make sure these permissions are not tainting any of the following tests results: https://developer.android.com/reference/android/app/UiAutomation#dropShellPermissionIdentity()


### Warning logs: should we worry about them?


When you will install some packages on an Android 15 system you might see some warning logs reported in logcat:

```
Signature permission {PERMISSION_NAME} for package {PACKAGE_NAME} ({PACKAGE_PATH}) not in signature permission allowlist 
```

You might see these in the logs although the tests/package does not actually need a special permission. This can happen through the manifest merger mechanism if the tests is using some library that uses some specific permissions, although the tests is just using some API that does not need any permission at all. 

So these logs give us some ideas about possible issues at install time, but that does not mean that there is something to fix, we need to fix just any exception about missing permissions.


### Summary


Android 15 is enforcing new rules for signature permissions on user builds. If you are getting some exception while running your component, there are different solutions depending on your case:
- platform service installed as part of the production build can use the allow-list mechanism as documented [here](https://source.android.com/docs/core/permissions/signature-permission-allowlist)
- tests packages will need to use UiAutomator [adoptShellPermissionIdentity](https://developer.android.com/reference/android/app/UiAutomation#adoptShellPermissionIdentity(java.lang.String[])) API to bypass this check, just as CTS tests do
