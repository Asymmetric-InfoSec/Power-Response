![alt text](https://github.com/Asymmetric-InfoSec/Power-Response/blob/master/Extras/PR_Logo.PNG "Sweet Power-Response Logo")
________________________________________________________________________________________________

Please note that Power-Response is **still under active development**. We will continue to add plugins and enhancements for the foreseeable future. If you have any requests, please submit an issue above. We also accept pull requests. If you have something you would like to contribute, we would love to see it.

## What is Power-Response?

Power-Response is a modular PowerShell Framework for Incident Response. The aim of Power-Response is to provide a framework that acts as a constient and highly usable tool by all members of an incident response team, as well as the jack of all trades that tends to have security fall into their lap as "additional duties as required." Power-Response helps to bridge the gap for analysts just getting into security, experienced forensicators looking for a common interface with their comrades, and everyone else in between by focusing on consolidated output methods, increased logging, and ease of data collection. 

## The Power is in the Plugins

Power-Response was developed to be a robust, flexible, and scalable framework with one job and one job only: to be a consolidated framework for a forensicator, analyst, or IT guru that allows them to use **ANY** plugin (which is a fancy way of saying PowerShell script) that their heart desires. This means that you can take your scripts that you have been using for years, place them into a location in your plugins directory and *boom!* you can use that plugin with Power-Response. You don't even need to restart Power-Response to have the plugin be recognized, just navigate into the plugin directory after you dropped a plugin where its new home will be and Power-Response will see it the next time you navigate there. 

We've given you the template that we use for creating our plugins (it's in the Extras directory). That should help keep things consistent if you are into that kind of thing. Also, when we say you can use any plugin you want, we mean it. Add whatever kind of scripts and plugins to Power-Response to begin your own incident response adventure. Have them do what you want and need them to do. Just know that Power-Response will make them all readily available to you in an easy to use framework.

Power-Response is simple, but it plays a vital role in rapid and flexible data collection. We wanted to give you the power to make Power-Response what you want it to be and to make it extremely effective for your own scenarios. 

## Power-Response Quick Start Guide

### Install Power-Response

Super easy, there is no formal installation required. Simply clone the reposity using git (git clone https://github.com/Asymmetric-InfoSec/Power-Response.git) or download the zip file and move into your desired location

**Note:** There isn't any directory dependencies, wheverever you want Power-Resposne to live will, Power-Response can live.

### Start Power-Response

Power-Response comes with pre-built plugins in the plugins directory of the repository (we will continue to add plugins as rapidly as possible), so you should be able to get going pretty quickly. Don't worry too much about any other directories, Power-Response will generate all necessary directories on the fly as needed. 

It is recommended that you run Power-Response in a user context that allows you to collect data on all target machines. We do have some methods around this using credential modules in PowerShell if needed (another plugin!).

Invoke Power-Response by executing `.\Power-Response.ps1` -> boom thats all there is to it. 

You will be dropped into an interactive menu style framework that will guide you to executing plugins to collect data on the target machine(s).

You will be able to navigate through the framework by making selections (pick a number) and that will either navigate to the next directory or will select a plugin for you to start data collection. 

If you get stuck, no worries, use the help menu described below.

### Power-Response Help Menu

As you navigate the framework, you may end up having questions about what you can and cannot do. At any given time, invoke the `help` command and you will be provided with commands that you can execute at your current position in the framework. The available commands will be all, or some, of the following:

**Name   ->   Description**

back     ->   de-select a script file and move back to menu context  
exit     ->   exits Power Response  
help     ->   displays the help for all or specified commands  
remove   ->   removes all or a specified parameter values  
run      ->   runs the selected script with parameters set in environment  
set      ->   sets a parameter to a value  
show     ->   shows a list of all or specified parameters and values  
clear    ->   clears the screen of clutter while running plugins  

### Data Collection and Plugin Execution with Power-Response

When you enter into a plugin, Power-Response will show you the parameters (both optional and required) that are available for the plugin. The parameters will also show you what parameter type they are (string, string array, integer, etc.) so you can provide the correct value type. To set a value for a parameter, you will use the set command.

Example: `set ComputerName test-pc` -- will set the ComputerName variable to "test-PC"

After you have set all parameters for the plugin, simply execute the `run` command and the plugin will run to completion. Don't worry, if there are errors during execution, Power-Response will let you know.

Any output generated will be moved to the **Output** directory and timestamped based on plugin run and time. By default, Power-Response will provide the plugin output in both XML and CSV format.

**Note:** As you navigate from plugin to plugin, Power-Response will attempt to maintain parameter values. For instance, if you set `ComputerName` in one plugin and navigate to another plugin to collect more data, the `ComputerName` parameter will already be assigned (as long as the parameter types are the same - see the Wiki for more details)

At anytime you can execute the `show` command to see what is available to you in a meny or plugin.

#### For a quick video tutorial, take a look at this video

#### Well, thats the basics. And truthfully, it's not much more complicated than that. Once you get in and do a little forensicating, you will catch on really quickly. For more details, take a look at the Wiki. Happy Forensicating!
