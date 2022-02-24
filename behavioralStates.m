function [freezing,quietWake,SWS,REM,movement] = behavioralStates(corticalLFP,hpcLFP,speed,speedTreshold,varargin)
%  behavioralStates     determines freezing, quiet wakefulness, slow wave sleep, and REM sleep based 
%                       on animal motor activity and LFP.
%
%  USAGE
%
%    [freezing,quietWake,SWS,REM] = behavioralStates(session,spindleChannel,thetaChannel,speed,speedTresh,<options>)
%
%    corticalLFP        cortical LFP with visible spindles (in [times values] format, 1250 Hz recommended)
%    hpcLFP             hippocampal LFP with good theta (set to empty to use cortical channel only)
%    speed              two-column matrix with time stamps in the first column and speed values in the second
%                       We recommend speed be smoothed with a Gaussian window of 1 s before calling behavioralStates.
%    speedTreshold      treshold value to define immobility
%    <options>          optional list of property-value pairs (see table below)
%
%    =============================================================================================================
%     Properties                Values
%    -------------------------------------------------------------------------------------------------------------
%     'immobilityTolerance'     maximum duration (s) of movements that are ignored when computing immobility periods  
%     'sleepMoveTolerance'      maximum duration (s) of movements that are ignored when computing sleep periods
%     'SWStoREMmaxTransition'   maximum duration (s) of SWS to REM transitions
%     'restPriorSWS'            duration (s) prior to SWS that cannot be freezing
%     'minSleepLenght'          minimun duration (s) of sleep periods
%     'freezingMoveTolerance'   maximum duration (s) of movements that are ignored when computing freezing
%    =============================================================================================================
%
%  OUTPUT
%
%    freezing       freezing periods intervals
%    quietWake      quiet wakefulness periods intervals
%    SWS            slow wave sleep periods intervals
%    REM            REM sleep periods intervals
%    movement       movement periods intervals
%
%
% Copyright (C) 2019-2022 by Ralitsa Todorova & Marco Pompili
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 3 of the License, or
% (at your option) any later version.
%% Default values
immobilityTolerance = 0.2;
sleepMoveTolerance = 1.5;
SWStoREMmaxTransition = 120;
restPriorSWS = 120;
minSleepLenght = 30;
freezingMoveTolerance = 0.2;
minFreezingLenght = 2;
QuietMoveTolerance = 0.5;
minQuietLenght = 2;
%% Parse options
for i = 1:2:length(varargin),
	if ~ischar(varargin{i}),
		error(['Parameter ' num2str(i+firstIndex) ' is not a property (type ''help <a href="matlab:help behavioralStates">behavioralStates</a>'' for details).']);
	end
	switch(lower(varargin{i})),
		case 'immobilityTolerance',
			immobilityTolerance = lower(varargin{i+1});
			if ~isdscalar(immobilityTolerance,'>=0'),
				error('Incorrect value for property ''immobilityTolerance'' (type ''help <a href="matlab:help behavioralStates">behavioralStates</a>'' for details).');
			end
		case 'sleepMoveTolerance',
			sleepMoveTolerance = lower(varargin{i+1});
            if ~isdscalar(sleepMoveTolerance,'>=0'),
                error('Incorrect value for property ''sleepMoveTolerance'' (type ''help <a href="matlab:help behavioralStates">behavioralStates</a>'' for details).');
            end
        case 'SWStoREMmaxTransition',
            SWStoREMmaxTransition = lower(varargin{i+1});
            if ~isdscalar(SWStoREMmaxTransition,'>=0'),
                error('Incorrect value for property ''SWStoREMmaxTransition'' (type ''help <a href="matlab:help behavioralStates">behavioralStates</a>'' for details).');
            end
        case 'restPriorSWS',
            restPriorSWS = lower(varargin{i+1});
            if ~isdscalar(restPriorSWS,'>=0'),
                error('Incorrect value for property ''restPriorSWS'' (type ''help <a href="matlab:help behavioralStates">behavioralStates</a>'' for details).');
            end
        case 'minSleepLenght',
            minSleepLenght = lower(varargin{i+1});
            if ~isdscalar(minSleepLenght,'>=0'),
                error('Incorrect value for property ''minSleepLenght'' (type ''help <a href="matlab:help behavioralStates">behavioralStates</a>'' for details).');
            end
        case 'freezingMoveTolerance',
            freezingMoveTolerance = lower(varargin{i+1});
            if ~isdscalar(freezingMoveTolerance,'>=0'),
                error('Incorrect value for property ''freezingMoveTolerance'' (type ''help <a href="matlab:help behavioralStates">behavioralStates</a>'' for details).');
            end  
        case 'minFreezingLenght',
            minFreezingLenght = lower(varargin{i+1});
            if ~isdscalar(minFreezingLenght,'>=0'),
                error('Incorrect value for property ''minFreezingLenght'' (type ''help <a href="matlab:help behavioralStates">behavioralStates</a>'' for details).');
            end
        case 'QuietMoveTolerance',
            QuietMoveTolerance = lower(varargin{i+1});
            if ~isdscalar(QuietMoveTolerance,'>=0'),
                error('Incorrect value for property ''QuietMoveTolerance'' (type ''help <a href="matlab:help behavioralStates">behavioralStates</a>'' for details).');
            end
        case 'minQuietLenght',
            minQuietLenght = lower(varargin{i+1});
            if ~isdscalar(minQuietLenght,'>=0'),
                error('Incorrect value for property ''minQuietLenght'' (type ''help <a href="matlab:help behavioralStates">behavioralStates</a>'' for details).');
            end
		otherwise,
			error(['Unknown property ''' num2str(varargin{i}) ''' (type ''help <a href="matlab:help behavioralStates">behavioralStates</a>'' for details).']);
	end
end
%% Get immobility periods
rangeTime = corticalLFP([1 end],1)';
tic
disp('Detecting immobility...')
speed(isnan(speed(:,2)),:) = [];
t = speed(:,1);
t0 = [0; speed(:,1); rangeTime(2)];
% Find intervals where speed data is missing
noData = [];
if any(diff(t0)>1)  
    noData = t0(bsxfun(@plus,FindInterval(diff(t0)>1),[0 1])); % more than 1s without data
end
immobility = t(FindInterval(speed(:,2)<speedTreshold));
immobility(diff(immobility,[],2)<immobilityTolerance,:) = []; % pauses < immobilityTolerance don't count
if size(immobility,2)==1, immobility = immobility'; end
movement = SubtractIntervals([0 speed(end,1)],[noData;immobility]); % these are the periods we should exclude when detecting sleep and freezing
% Make sure we're not excluding large periods of time with missing speed data: remove each 'movement' period for which we don't have data
midpoint = mean(movement,2);
bad = isnan(interp1(speed(:,1),speed(:,2),midpoint));
movement(bad,:) = [];
elapsedTime = toc;
fprintf('...done! (this took %.2f seconds)\n',elapsedTime);
%% Get high spindle power periods and (sw)sleep
tic
disp('Detecting Slow Wave Sleep...')
spindleLFP = FilterLFP(corticalLFP,'passband',[9 17]);
[~,bad,noisyIntervals] = CleanLFP(spindleLFP);
tLFP = spindleLFP(:,1);
badPeriods = tLFP(FindInterval(bad));
noData = ConsolidateIntervals(sortrows([noData;badPeriods]));
[~,spindlePower] = Phase(spindleLFP);
spindlePower(bad,2) = nan;
spindlePower = Shrink(spindlePower,1250,1); % downsample to one value per second
tSpindles = spindlePower(:,1);
smoothedPower = spindlePower(:,end); smoothedPower(~isnan(smoothedPower)) = Smooth(spindlePower(~isnan(smoothedPower),end),14); % smooth with a 14-s window
k = kmeans(smoothedPower,2); % two clear groups, the distribution should be obviously bimodal
if mean(smoothedPower(k==1))>mean(smoothedPower(k==2)), k=3-k; end % Make sure k=2 corresponds to the high spindlepower group
highSpindles = tSpindles(FindInterval(k==2));
SWS = SubtractIntervals(highSpindles, movement); % Take only the overlap of high spindle power and no movement epoch
SWS = ConsolidateIntervals(SWS,'epsilon',sleepMoveTolerance); %animals can move briefly during sleep
SWS(diff(SWS,[],2)<minSleepLenght,:) = []; % sleep needs to be at least minSleepLenght long
elapsedTime = toc;
fprintf('...done! (this took %.2f seconds)\n',elapsedTime);
%% Get high theta/delta periods and REM sleep
tic
disp('Detecting REM sleep...')
if ~isempty(hpcLFP)
    hpcLFP(:,2) = zscore(hpcLFP(:,2));
    [w,wTimestamps,wFrequencies] = helper_WaveletSpectrogram(hpcLFP,'range',[1 15],'resolution',1);
    q = Smooth(Shrink(w,1,2500),[0 1]);
    t = Shrink(wTimestamps(:),2500,1);
    REM = t(FindInterval(q(4,:)>nanmean(q(1:3,:)))); % if power in the theta frequency band (7.5 Hz) is higher than low frequency power
else
    corticalLFP(:,2) = zscore(corticalLFP(:,2));
    [w,wTimestamps,wFrequencies] = helper_WaveletSpectrogram(corticalLFP,'range',[1 15],'resolution',1);
    q = Smooth(Shrink(w,1,2500),[0 1]);
    t = Shrink(wTimestamps(:),2500,1);
    thetaDelta = q(4,:)./nanmean(q(1:3,:));
    smoothedThetaDelta = Smooth(thetaDelta,8);
    [kk,threshold,em(i+1)] = Otsu(smoothedThetaDelta);
    if max(minmax(smoothedThetaDelta(kk==1)))<max(minmax(smoothedThetaDelta(kk==2))) && sum(kk==2)<sum(kk==1)
        REM = t(FindInterval(kk'==2));
    elseif max(minmax(smoothedThetaDelta(kk==2)))<max(minmax(smoothedThetaDelta(kk==1))) && sum(kk==1)<sum(kk==2)
        REM = t(FindInterval(kk'==1));
    else
        error('more REM intervals than SWS')
    end        
end
% First, make the REM period terminate if the animal moved
yes = 0;
for j=1:size(REM)
    idx = find(movement(:,1)>REM(j,1),1);
    if movement(idx,1)<REM(j,2)
        REM(j,2) = movement(idx,1);
        yes = yes+1;
    end
end
% remove REM periods not preceded by SWS
bad = ~IntervalsIntersect([REM(:,1)-SWStoREMmaxTransition REM(:,1)],SWS);
REM(bad,:) = [];
REM = SubtractIntervals(REM, SWS); % REM epochs cannot be SWS
REM = ConsolidateIntervals(REM,'epsilon',sleepMoveTolerance);
REM(diff(REM,[],2)<minSleepLenght,:) = []; % sleep needs to be at least minSleepLenght long
elapsedTime = toc;
fprintf('...done! (this took %.2f seconds)\n',elapsedTime);
%% Get freezing
tic
disp('Detecting freezing...')
addTimeAround = @(x) [x(:,1)-restPriorSWS x(:,2)]; % add 120 s before each sleep epoch; this cannot be freezing
nonfreezing = sortrows([addTimeAround(SWS); movement; noisyIntervals; addTimeAround(REM)]); % If data were too noisy to detect SWS/REM that would not mean the animal is freezing
freezing = SubtractIntervals(rangeTime,sortrows([nonfreezing;noData]));
freezing = ConsolidateIntervals(freezing,'epsilon',freezingMoveTolerance);
freezing(diff(freezing,[],2)<minFreezingLenght,:) = []; % freezing needs to be at least minFreezingLenght long
elapsedTime = toc;
fprintf('...done! (this took %.2f seconds)\n',elapsedTime);
%% Get quietWake
tic
disp('Detecting quiet wakefulness...')
quietWake = SubtractIntervals(rangeTime,[REM;SWS;freezing;movement;noisyIntervals]);
quietWake = ConsolidateIntervals(quietWake,'epsilon',QuietMoveTolerance);
quietWake(diff(quietWake,[],2)<minQuietLenght,:) = [];
elapsedTime = toc;
fprintf('...done! (this took %.2f seconds)\n',elapsedTime);
end