function trendX=generateTrendModel(nTimePoints,highestFreq_nCycles,linearTerm,monitor)

% USAGE
%   trendX=generateTrendModel(nTimePoints,highestFreq_nCycles,linearTerm,monitor)

if ~exist('monitor')
    monitor=0;
end

range=[1:nTimePoints]';
trendX=[];

for nCycles=1:highestFreq_nCycles
    period=nTimePoints/nCycles;
    trendX=[trendX,sin(range/period*2*pi),cos(range/period*2*pi)];
    
end

if linearTerm
    ramp=range/nTimePoints;
    ramp=ramp-mean(ramp);
    trendX=[trendX,ramp];
end

if monitor
    figure(184); clf;
    plot(trendX);
end