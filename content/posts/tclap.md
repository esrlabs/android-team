---
title: "Using TCLAP to parse dumpsys commands"
date: 2024-10-08
draft: false
author: ccombei-esrlabs
---

## Introduction
The `Templatized C++ Command Line Parser` is a c++ header library that is used to parse command line arguments. The developers of this library maintain a manual (https://tclap.sourceforge.net/manual.html) that is easy to use, so be sure to check it out. You can use it for any c++ component that can be debugged with "dumpsys".  

## Setup
In order to use TCLAP, first we must:  
- copy the sources to extern/tcalp (https://sourceforge.net/projects/tclap/files/)
- create the Android.bp file

```
cc_library_headers {
    name: "tclap",
    export_include_dirs: [ "include" ],
    host_supported: true,
    device_supported: true,
    product_specific: true,
    vendor_available: true
}
```

## Usage
In order to use this library to parse your dumpsys commands, you can just copy the following code and adapt the todos to fit your needs

```c++
binder_status_t <your_class>::dump(int fd, const char **argv, uint32_t argc) {

    // because dumpsys is printing to a custom file descriptor and tclap uses cout and cerr
    // to do the printing, we have to redirect everything to a local buffer that we will print
    // at the end of this function. Because of this limitation, this function must have only
    // 1 return point (otherwise, we need to copy-paste code around)
    ::std::stringstream buffer;
    ::std::streambuf *old_cout = ::std::cout.rdbuf(buffer.rdbuf());
    ::std::streambuf *old_cerr = ::std::cerr.rdbuf(buffer.rdbuf());

    try {
          ::TCLAP::CmdLine cmd("<short_description_of_what_this_command_line_is_for>", ' ', "1.0", true);
        // configure commands

        // we need to handle all exceptions ourselves, because, if TCLAP finds an exception, it will
        // also invoke the "exit" function which will terminate the process that contains this instance
        // of TCLAP
        cmd.setExceptionHandling(false);

        // because TCLAP was meant as a command line tool that expects the program name as argv[0]
        // and we receive the parameters without the program name, it is necessary that we insert
        // the program name as argv[0] so we do not have to change the TCLAP library
        ::std::vector<std::string> argsAsVect;
        argsAsVect.push_back("<name_of_your_service_that_appears_after_dumpsys>");
        for (uint32_t i = 0; i < argc; ++i) {
            ::std::string next_argv(argv[i]);
            argsAsVect.push_back(next_argv);
        }

        // todo: add the possible commands that can be invoked
        // (see https://tclap.sourceforge.net/manual.html)

        cmd.parse(argsAsVect);

        // todo: process the commands

    } catch (::TCLAP::ArgException &e) {
        ::std::cerr << "error: " << e.error() << " for arg " << e.argId() << ::std::endl;
    } catch (const ::TCLAP::CmdLineParseException &e) {
        std::cerr << e.what() << std::endl;
    } catch (const ::TCLAP::ExitException &e) {
    }

    dprintf(fd, "%s", buffer.str().c_str());
    ::std::cerr.rdbuf(old_cerr); // reset to standard error again
    ::std::cout.rdbuf(old_cout); // reset to standard output again
    return EX_NONE;
}
```

Update Android.bp with the dependency on TCLAP  
```
cc_binary {
    ...
    header_libs: [
        "tclap"
    ],
    ...
}
```

## Android specifics
Because TCLAP was meant to be used as a stand-alone program that, once invoked, does some work and then dies, and in our case, the process that implements the dumpsys function should not be killed after the dumpsys command call, it means that we have to configure the library in an unconventional way. These constraints are already part of the upper mentioned code.

* **Redirect the output of cout and cerr to a string stream:** because dumpsys uses a custom file descriptor and TCLAP uses std::cout and std::cerr function calls, it is necessary that we redirect the std::cout and std::cerr outputs to a local buffer that we will print to the custom file descriptor. This approach creates one constraint: the function must have only one return point. If you want to have multiple return points, then before each return statement, you must print to the custom file descriptor and reset the standard output and error again.
* **Handle all exceptions:** by default, TCLAP handles the exceptions on its own. If an exception is detected, then TCLAP outputs a log and then calls the "exit" function, which will result in the operating system terminating the process. This is why we must tell TCLAP to not handle any exceptions and to simply throw them. If we do not catch these exceptions, then they will be thrown all the way to lib bionic, which will also
result in the process being terminated (SIG 6 will be sent to this process).
* **Insert the first parameter of dumpsys into the argument list:** TCLAP expects the program name as argv[0], but dumpsys is giving use the arguments without the object name that triggered this function. This is why
we need to recreate the argument list before parsing it.
* **Handling complex parameters:** TCLAP can handle simple command line parameters, like "-p <val>" or  "--flag", but if you have something like a command that takes two integers and a vector of integers as parameters (ie. "-p <val> <val> <val>,<val>,<val>"), then TCLAP does not give you many options. The best way to handle those parameters is to have them encapsulated between ""
(eg. dumpsys <your_service> -p "1 1 2,1,3"). By doing this, TCLAP will consider everything that is encapsulated between "" as one parameter. This one parameter then you will have to parse individually.