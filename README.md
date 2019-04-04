![alt text](https://github.com/Asymmetric-InfoSec/Power-Response/blob/master/Extras/PR_Logo.PNG "Sweet Power-Response Logo")

Drew Schmitt | Matt Weikert | Gavin Prentice
________________________________________________________________________________________________

Please note that Power-Response is **still under active development**. We will continue to add plugins and enhancements for the foreseeable future. If you have any requests, please submit an issue above. We also accept pull requests. If you have something you would like to contribute, send up a pull request for us to take a look. Please check the wiki for details on best practices for developing plugins for Power-Response.

## What is Power-Response?

Power-Response is a modular PowerShell Framework for Incident Response. The aim of Power-Response is to provide a framework that acts as a constient and highly usable tool by all members of an incident response team, or other roles that require the ability to rapidly collect data during security incidents while focusing on consolidated output methods, increased logging, and ease of data collection. 

## The Power is in the Plugins

Power-Response was developed to be a robust, flexible, and scalable framework with one job: to be a consolidated framework that allows them to use any plugin (i.e. PowerShell script) to collect data from any interesting endpoint. This means that you can take your scripts that you have been using for years, place them into a location in your plugins directory and you can use that plugin with Power-Response. 

We've given you the template that we use for creating our plugins (it's in the Extras directory). Also, you really can use any plugin that you want. You just need to drop them into a location that is located under the plugins directory. Power-Response will make them all readily available to you in an easy to use menu style framework.

## Power-Response Quick Start Guide

### Install Power-Response

There is no formal installation required. Simply clone the reposity using git (git clone https://github.com/Asymmetric-InfoSec/Power-Response.git) or download the zip file and move into your desired location

**Note:** There isn't any directory dependencies for where the root directory of Power-Response needs to live.

### Dependencies

Download and/or place the follwing dependencies into `BIN`

#### Sysinternals Tools

The following Sysinternals tools are required for Sysinternals based plugins:

1. `Autorunsc.exe`
2. `Autorunsc64.exe`
3. `Sigcheck.exe`
4. `Sigcheck64.exe`
5. `Handle.exe`
6. `Handle64.exe`

#### Winpmem Memory Acquisition Tool

Winpmem is used for memory acquisition on Windows based machines:

1. Download the most recent release of Winpmem from https://github.com/Velocidex/c-aff4/releases/
2. Rename the executable to `winpmem.exe`
3. Move winpmem.exe to `BIN`

Big shout out to Michael Cohen for his work on winpmem!

#### 7-zip Stand Alone Compression Tool

PowerShell (.NET actually) has some native limitations for compression (must be less than 2GB), so we needed to bring in a stand alone tool to do compression on our behalf:

1. Download `7-Zip Extra: standalone console version, 7z DLL, Plugin for Far Manager` from https://www.7-zip.org/download.html
2. Locate the 64bit executable and rename to `7za_x64.exe`
3. Locate the 32bit executable and rename to `7za_x86.exe`
4. Move both executables to `BIN`

#### Velociraptor Stand Alone Tool

To get around locked files, we decided to use the default binary from the Velociraptor project:

1. Download `velociraptor-vx.x.x-windows-4.0-amd64.exe` and `velociraptor-vx.x.x-windows-4.0-386.exe`
   from https://github.com/Velocidex/velociraptor/releases (Whatever the latest versions are)
2. Rename the files to `velociraptor-amd64.exe` and `velociraptor-386.exe` respectively
3. Move executable to `BIN`

Another big shout out to Michael Cohen for his work on Velociraptor!

#### Eric Zimmerman's Tools

We use the following executables from Eric's tools that can be found at https://ericzimmerman.github.io/#!index.md

1. `PECmd`
2. `JLECmd`
3. `LECmd`

Huge shout out to Eric and his tools! They make easy analysis work of the data that Power-Response collects.

### Start Power-Response

Power-Response comes with pre-built plugins in the plugins directory of the repository (we will continue to add plugins as rapidly as possible), so you should be able to get going pretty quickly. Don't worry too much about any other directories, Power-Response will generate all necessary directories on the fly as needed. 

It is recommended that you run Power-Response in a user context that allows you to collect data on all target machines. 

Invoke Power-Response by executing `.\Power-Response.ps1`

You will be dropped into an interactive menu style framework that will guide you through executing plugins to collect data on the target machine(s).

You will be able to navigate through the framework by making selections (pick a number) and that will either navigate to the next directory or will select a plugin for you to start data collection. 

### Power-Response Help Menu

As you navigate the framework, you may end up having questions about what you can and cannot do. At any given time, invoke the `help` command and you will be provided with commands that you can execute at your current position in the framework. The available commands will be all, or some, of the following:

**Name:   Description**

`back`: de-select a script file and move back to menu context  
`exit`: exits Power Response  
`help`: displays the help for all or specified commands  
`remove`: removes all or a specified parameter values  
`run`: runs the selected script with parameters set in environment  
`set`: sets a parameter to a value  
`show`: shows a list of all or specified parameters and values  
`clear`: clears the screen of clutter while running plugins  

### Data Collection and Plugin Execution with Power-Response

When you enter into a plugin, Power-Response will show you the parameters (both optional and required) that are available for the plugin. The parameters will also show you what parameter type they are (string, string array, integer, etc.) so you can provide the correct value type. To set a value for a parameter, you will use the set command.

Example: `set ComputerName test-pc` -- will set the ComputerName variable to "test-PC"

After you have set all parameters for the plugin, simply execute the `run` command and the plugin will run to completion. If there are errors during execution, Power-Response will let you know.

Any output generated will be moved to the **Output** directory and named based on plugin run and timestamp. By default, Power-Response will provide the plugin output in both XML and CSV format.

**Note:** As you navigate from plugin to plugin, Power-Response will attempt to maintain parameter values. For instance, if you set `ComputerName` in one plugin and navigate to another plugin to collect more data, the `ComputerName` parameter will already be assigned (as long as the parameter types are the same - see the Wiki for more details)

At anytime you can execute the `show` command to see what is available to you in a meny or plugin.

#### For a quick video tutorial, take a look at this video
