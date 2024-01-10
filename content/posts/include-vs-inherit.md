---
title: "Device configuration: include vs inherit-product"
date: 2023-12-29T16:19:07+01:00
draft: false
author: "Ciprian Talaba"
---

I had to work quite a lot with device configuration in Android and one big question that I had was what is the difference between "include" and "inherit-product" a device makefile. This post will try to answer that, but I will tell you it's a long story.

Including a device makefile works just as you would expect: it's basically like copying the entire code from the included file into the current makefile. This means that all the variables are taken into account, and we need to make sure that the included file does not override any important variables for us (always pay attention on using := operator).

When I started to look into the inherit-product usage I started with looking on how Google is working with the device makefiles. Searching for "include" in the entire device/generic directory of Android 13 brings ~180 lines, but most of them are board configs and basic Android.mk files, no very little usage in the product makefiles.

In the same time searching for "inherit-product" leads to ~190 lines all of them in the product makefiles, so this seems to be the way that Google recommends. But I don't like to use something that I don't really understand, so let's dig a little bit into the actual code.

The actual implementation of "inherit-product" is defined in build/make/core/product.mk:

```
# To be called from product makefiles, and is later evaluated during the import-nodes
# call below. It does the following:
#  1. Inherits all of the variables from $1.
#  2. Records the inheritance in the .INHERITS_FROM variable
#
# (2) and the PRODUCTS variable can be used together to reconstruct the include hierarchy
# See e.g. product-graph.mk for an example of this.
#
define inherit-product
  $(eval _inherit_product_wildcard := $(wildcard $(1)))\
  $(if $(_inherit_product_wildcard),,$(error $(1) does not exist.))\
  $(foreach part,$(_inherit_product_wildcard),\
    $(if $(findstring ../,$(part)),\
      $(eval np := $(call normalize-paths,$(part))),\
      $(eval np := $(strip $(part))))\
    $(foreach v,$(_product_var_list), \
        $(eval $(v) := $($(v)) $(INHERIT_TAG)$(np))) \
    $(eval current_mk := $(strip $(word 1,$(_include_stack)))) \
    $(eval inherit_var := PRODUCTS.$(current_mk).INHERITS_FROM) \
    $(eval $(inherit_var) := $(sort $($(inherit_var)) $(np))) \
    $(call dump-inherit,$(strip $(word 1,$(_include_stack))),$(1)) \
    $(call dump-config-vals,$(current_mk),inherit))
endef
```

The comment above the implementation should help, but actually it creates more confusion if we compare it with the actual implementation. We can see that the code is checking if the file exists, if does some path normalization if needed and then it actually looks for all the variables into a product_var_list. Hmmmm...

So it does not inherit **all** the variables, just the ones in that list. It seems to be defined in the same product.mk file as the function:
```
product_var_list :=$= $(_product_single_value_vars) $(_product_list_vars)
```
So basically we have 2 lists, one with single value variables and one with list variables, and the common part if that all of them starts with **PRODUCT_**. I will not list them here because they might change, I recommend to have a look into the AOSP file to check them out. There are 4 exceptions to this naming rule:
```
DEVICE_PACKAGE_OVERLAYS
VENDOR_PRODUCT_RESTRICT_VENDOR_FILES
VENDOR_EXCEPTION_MODULES
VENDOR_EXCEPTION_PATHS
```

I found one interesting comment in that file that is relevant for the single value variables, and how their inheritance will work (will put this to the test later):

```
# Variables that are meant to hold only a single value.
# - The value set in the current makefile takes precedence over inherited values
# - If multiple inherited makefiles set the var, the first-inherited value wins
```

Seems pretty straightforward now, but let's put this to the test. I created a small test device that is inheriting from the AOSP Car Emulator device, you can browse all the files [on Github](https://github.com/esrlabs/android-team/tree/main/content/posts/incldue-vs-inherit).

The main part is in esr_emulator.mk, where we try to inherit some other files:

```
$(call inherit-product, device/generic/car/emulator/aosp_car_emulator.mk)
$(call inherit-product, build/target/product/aosp_x86_64.mk)

EMULATOR_VENDOR_NO_SOUND := true
PRODUCT_NAME := esrlabs_car_x86
PRODUCT_DEVICE := generic_car_x86
PRODUCT_BRAND := ESRLabs
PRODUCT_MODEL := ESRLabs Car on x86 emulator

$(call inherit-product, device/esrlabs/car-emu/common.mk)
```

And then in Android.mk where we define a fake target that is only used to print the actual values of from product variables:
```
LOCAL_PATH := $(call my-dir)

# Statically create folder under /vendor partition
# This is done to provide read-write folder under read-only 
# vendor partition.
include $(CLEAR_VARS)
$(warning brand: $(PRODUCT_BRAND))
$(warning cache: $(PRODUCT_BUILD_CACHE_IMAGE))
$(warning gps: $(EMULATED_GPS))
LOCAL_MODULE := CreateESRFolder
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)
LOCAL_POST_INSTALL_CMD := mkdir -p $(TARGET_OUT_VENDOR)/esrlabs
```

We also have a small file that we will use to inherit:

```
#common.mk
PRODUCT_BRAND := Accenture
PRODUCT_BUILD_CACHE_IMAGE := true
EMULATED_GPS := false
```

So, let's see what tests we can do, to better understand how inherit-product works.

### Test 1 - local definition override any inheritance

We will inherit common.mk at the end of device makefile

Expectation: 
```
brand: ESRLabs
cache: true
gps: false
```
Actual output:
```
brand: ESRLabs
cache: true
gps: false
``````

That seems to confirm that the value that we set in the device makefile for PRODUCT_BRAND will take over any inheritance.

### Test 2 - first inheritance is the one that is used

We will comment out PRODUCT_NAME from the device makefile and inherit common.mk at the end of device makefile

Expectation: 
```
brand: Android (coming from the car emulator, which is inherited first)
cache: true
gps: false
```
Actual output:
```
brand: Android
cache: true
gps: false
``````

So far so good, everything seems to line up with the comments in the code.

### Test 3- first inheritance is the one that is used

We will comment out PRODUCT_NAME from the device makefile and inherit common.mk at the beginning of device makefile, before inheriting from aosp_car_emulator.mk

Expectation: 
```
brand: Accenture (coming from common.mk, which is inherited first)
cache: true
gps: false
```
Actual output:
```
brand: Android
cache: true
gps: false
``````
Ok, that is not what I expected, it does not look to use the value from the first inherited file, so a bit more debugging is needed.

I started with printing the value of the PRODUCT_BRAND variable in the device makefile:

```
brand: @inherit:device/esrlabs/car-emu/common.mk @inherit:device/generic/car/emulator/aosp_car_emulator.mk @inherit:build/make/target/product/aosp_x86_64.mk
```

Ok, that inhereitance list seems to be fine, common.mk is the first one there, but the value is still not currect.

I then started to look again at the implementation of inherit-product and I noticed that the inheritance list is also sorted:
```
$(eval inherit_var := PRODUCTS.$(current_mk).INHERITS_FROM) \
$(eval $(inherit_var) := $(sort $($(inherit_var)) $(np))) \
```

Ok, so let's print the value of PRODUCTS.device/esrlabs/car-emu/esr_emulator.mk.INHERITS_FROM and see what we get:
```
inherit_var: build/make/target/product/aosp_x86_64.mk device/esrlabs/car-emu/common.mk device/generic/car/emulator/aosp_car_emulator.mk
```
Ok. so it seems like the inheritance list is sorted by the full path and everything in build/ will take precedence over everthing in device/. Let's test this behaviour.

### Test 4 - inheritance is used in alphabetical order

Same as test 3 but move common.mk into it's own **atest/** directory in the root of the AOSP tree so that it will come before files located in build/.

Expectation: 
```
brand: Accenture
cache: true
gps: false
```
Actual output:
```
inherit_var: atest/common.mk build/make/target/product/aosp_x86_64.mk device/generic/car/emulator/aosp_car_emulator.mk
brand: Accenture
cache: true
gps: false
```

Ok, so that seems to work as we expected. We have one more test to do before the summary.

### Test 5 - definition from include file overrides inheritance

Same as test 3 but include common.mk at the end instead of inheriting from it.

Expectation: 
```
brand: Accenture (the include will set the variable just like it would be in the device makefile)
cache: true
gps: false
```
Actual output:
```
brand: Accenture
cache: true
gps: false
```

Ok, just as expected. That also proves that include works just like copying the code inside our main makefile.

### Summary

While inherit-product seems to be the recommended Google way of working with device makefiles we need to take into account a few things:
- only specific variables will be inherited, the list can easily change between Android versions
- inheritance is used in alphabetical order of the **full path** of the inherited file
- any PRODUCT variables that we inherit from build/ will take precedence over anything inherited from our device tree
- to be sure we end up with the desired values we should just define our own values in the main device makefile (or in any included files) instead or relying on inheritance from our own tree.