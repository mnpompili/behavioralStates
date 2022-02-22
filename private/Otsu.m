function [group,threshold,em] = Otsu(vector)

% The Otsu method for splitting data into two groups.
% This is somewhat equivalent to kmeans(vector,2), but while the kmeans implementation
% finds a local minimum and may therefore produce different results each time,
% the Otsu implementation is guaranteed to find the best division every time.
%
% Copyright (C) 2021 by Ralitsa Todorova
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 3 of the License, or
% (at your option) any later version.

if size(vector,2)>1
    for i=1:size(vector,2)
        [group(:,i),threshold(i),em(i)] = Otsu(vector(:,i));
    end
    return
end

sorted = sort(vector);
intraClassVariance = nan(size(vector));
n = length(vector);
parfor i=1:n-1
    p = (i)/n; p0 = 1-p;
    intraClassVariance(i) = p*var(sorted(1:i),1)+ p0*var(sorted(i+1:end),1);
end
[minIntraVariance,idx] = min(intraClassVariance);
threshold = sorted(idx);
group = (vector > threshold)+1-1;

em = 1 - (minIntraVariance/var(vector,1)); % em = effectiveness metric
