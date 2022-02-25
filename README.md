# behavioralStates: a MATLAB function to determine rodents behavioral states based on motor activity and LFP/EEG recording

[**behavioralStates**](https://github.com/mnpompili/behavioralStates) is an open-source MATLAB function to automatically detected behavioral and brain states in rodents freely moving electrophsyiology experiments.

This function applies an algorithm described in [Pompili and Todorova (2022)](www.addresstothepaper.com), a work motivated by the need to automatically discriminate freezing from sleep states, which was not possible with previously available sleep detection techniques in the absence of olfactory bulb recordings. This method only requires 1) data about animal motor activity (which can be retrieved from video recording, position tracking, EMG, inertial measurements, or other sensors) and 2) at least 1 channel of cortical LFP/EEG recordings.  

Briefly **behavioralStates**: 
1) Detects immobility from speed data.  
2) Among immobility periods, SWS is then detected with the smoothed spindle power. 
3) From the remaining immobility, REM sleep is marked by high theta/delta periods following SWS. 
4) Finally, what is left is freezing, a part from the immobility preceding SWS marked as quiet wakefulness.

## Installation

Requirements:

* MATLAB >= R2016b
* MATLAB Toolboxes:
  * Signal Processing Toolbox
  * Statistics and Machine Learning Toolbox
  * Parallel Computing Toolbox (optional for increased speed)

The folder **private** include all the helper functions needed by behavioralStates to execute and must be placed in the same folder where *behavioralStates.m* is located.

## Usage

```matlab
[freezing,quietWake,SWS,REM] = behavioralStates(session,spindleChannel,thetaChannel,speed,speedTresh,<options>)
```
where:
* **corticalLFP** : cortical LFP with visible spindles (in [times values] format, 1250 Hz recommended),
* **hpcLFP** (optional) : hippocampal LFP with good theta (set to empty to use cortical channel only),
* **speed** :  two-column matrix with time stamps in the first column and speed values in the second. We recommend speed be smoothed with a Gaussian window of 1 s before calling behavioralStates.
* **speedTreshold** : treshold value to define immobility,
* **options** : optional list of property-value pairs (see table below).

| Properties  | Values |
| ------------- | ------------- |
| immobilityTolerance  | maximum duration (s) of movements that are ignored when computing immobility periods  |
| sleepMoveTolerance  | maximum duration (s) of movements that are ignored when computing sleep periods  |
| SWStoREMmaxTransition | maximum duration (s) of SWS to REM transitions |
| restPriorSWS | duration (s) prior to SWS that cannot be freezing |
| minSleepLenght | minimun duration (s) of sleep periods |
| freezingMoveTolerance | maximum duration (s) of movements that are ignored when computing freezing |

OUTPUT:
* **freezing** : freezing periods intervals
* **quietWake** : quiet wakefulness periods intervals
* **SWS** : slow wave sleep periods intervals
* **REM** : REM sleep periods intervals
* **movement** : movement periods intervals

## Credits

**behavioralStates** is developed and maintained by [Ralitsa Todorova](https://braincomputation.org/people/) and [Marco Pompili](http://www.normalesup.org/~pompili/)

## Questions

Please create an issue for bugs / usage problems.

## Licence

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

