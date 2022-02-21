function [freezing,quietWake,SWS,REM] = behavioralStates(session,spindleChannel,thetaChannel,speed,speedTresh,varargin)
%  behavioralStates     determines freezing, quiet wakefulness, slow wave sleep, and REM sleep based 
%                       on animal motor activity and LFP.
%
%  USAGE
%
%    [freezing,quietWake,SWS,REM] = behavioralStates(session,spindleChannel,thetaChannel,speed,speedTresh,<options>)
%
%    spindleChannel     channel to use for spindle LFP
%    thetaChannel       channel to use for theta LFP 
%    speed              two-column matrix with time stamps in the first column and speed values in the second
%    speedTresh         treshold value to define immobility
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
%
%  SEE
%
%    See also angularSpeed to compute animal speed from gyroscopic data.
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
minQuietLenght = 2
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
%% Retrieve session info
SetCurrentSessionParameters(session,'verbose','off');
[folder,sessionID] = fileparts(session);
events = LoadEvents(fullfile(folder,[sessionID '.cat.evt']));
catIntervals = reshape(events.time,2,[])';
%% get LFP data
tic
disp('loading LFP...')
pfcLFP = GetLFP(spindleChannel,'chunksize',120000);
hpcLFP = GetLFP(thetaChannel,'chunksize',120000);
elapsedTime = toc;
fprintf('...done! (this took %.2f seconds)\n',elapsedTime);
%% Get immobility periods
tic
disp('Detecting immobility...')
speed(isnan(speed(:,2)),:) = [];
t = speed(:,1);
t0 = [0; speed(:,1); max(catIntervals(:))];
% Find holes in data:
noData = [];
if any(diff(t0)>1)  
    noData = t0(bsxfun(@plus,FindInterval(diff(t0)>1),[0 1])); % more than 1250s without data
end
speed(:,2) = Smooth(speed(:,2),10);
immobility = t(FindInterval(speed(:,2)<speedTresh));
immobility(diff(immobility,[],2)<immobilityTolerance,:) = []; % pauses < immobilityTolerance don't count
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
spindleLFP = Filter0(pfcLFP,[9 17]);
% remove from final function for the public
ratNumber = @(x) str2double(x((3:5)+min(strfind(lower(x),'rat'))));
rat = ratNumber(sessionID);
if rat==386 | rat== 392 & ~ismember(spindleChannel,[19 76]) | rat==370, [~,bad] = CleanLFP(spindleLFP,'thresholds',[10 10]);
elseif  rat==399 | rat==401, [~,bad] = CleanLFP(spindleLFP,'thresholds',[7 10]);
else  [~,bad] = CleanLFP(spindleLFP,'thresholds',[5 10]);
end
tLFP = spindleLFP(:,1);
badPeriods = tLFP(FindInterval(bad));
noData = ConsolidateIntervals(sortrows([noData;badPeriods]));
[~,spindlePower] = Phase(spindleLFP);
spindlePower(bad,2) = nan;
spindlePower = Shrink(spindlePower,1250,1); % downsample to one value per second
tSpindles = spindlePower(:,1);
smoothedPower = nansmooth(spindlePower(:,end),14); % smooth with a 14-s window
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
hpcLFP(:,2) = zscore(hpcLFP(:,2));
[w,wt,wf] = WaveletSpectrogramRaw(hpcLFP,'range',[1 15],'resolution',1);
q = Smooth(Shrink(w,1,2500),[0 1]);
t = Shrink(wt(:),2500,1);
if spindleChannel~=thetaChannel
    REM = t(FindInterval(q(4,:)>nanmean(q(1:3,:)))); % if power in the theta frequency band (7.5 Hz) is higher than low frequency power
else
    thetaDelta = q(4,:)./nanmean(q(1:3,:));
    smoothedThetaDelta = Smooth(thetaDelta,8);
    [kkk,threshold,em(i+1)] = Otsu(smoothedThetaDelta);
    if max(minmax(smoothedThetaDelta(kkk==1)))<max(minmax(smoothedThetaDelta(kkk==2))) && sum(kkk==2)<sum(kkk==1)
        REM = t(FindInterval(kkk'==2));
    elseif max(minmax(smoothedThetaDelta(kkk==2)))<max(minmax(smoothedThetaDelta(kkk==1))) && sum(kkk==1)<sum(kkk==2)
        REM = t(FindInterval(kkk'==1));
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
nonfreezing = sortrows([addTimeAround(SWS); movement; addTimeAround(REM)]);
freezing = SubtractIntervals(catIntervals([1 end]),sortrows([nonfreezing;noData]));
freezing = ConsolidateIntervals(freezing,'epsilon',freezingMoveTolerance);
freezing(diff(freezing,[],2)<minFreezingLenght,:) = []; % freezing needs to be at least minFreezingLenght long
elapsedTime = toc;
fprintf('...done! (this took %.2f seconds)\n',elapsedTime);
%% Get quietWake
tic
disp('Detecting quiet wakefulness...')
quietWake = SubtractIntervals(catIntervals([1 end]),[REM;SWS;freezing;movement]);
quietWake = ConsolidateIntervals(quietWake,'epsilon',QuietMoveTolerance);
quietWake(diff(quietWake,[],2)<minQuietLenght,:) = [];
elapsedTime = toc;
fprintf('...done! (this took %.2f seconds)\n',elapsedTime);
end