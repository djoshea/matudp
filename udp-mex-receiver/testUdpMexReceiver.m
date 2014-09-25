% build_udpMexReceiver;
% to be used with testSerializeWithMultiUDP.mdl

udpMexReceiver('start');

figure(1), clf; set(1, 'Color', 'w');

subplot(1, 2, 1);
hold on

nPts = 100;
xData = nan(nPts, 1);
yData = nan(nPts, 1);
h = plot(xData, yData, 'g-', 'LineWidth', 2);
xlabel('X');
ylabel('Y');
title('Data from UDP');
xlim([-1.5 1.5]);
ylim([-1.5 1.5]);
box off

subplot(1,2,2);
tocVec = nan(1000, 1);
hToc = plot(tocVec, 'k.');
xlim([1 length(tocVec)]);
ylim([0 2]);
xlabel('Poll iteration');
ylabel('Time (ms)');
title('Mex Function Time');
box off

fprintf('Waiting for data from xPC...\n');


while(true)
   tocVec = [tocVec(2:end); NaN];
   tic
   g = udpMexReceiver('poll');
   if ~isempty(g)
    value = double(g(end).signals.x);
    timestamp = uint32(g(end).signals.t);
    udpMexReceiver('send', '#', value, timestamp);
   end
   tocVec(end) = toc*1000;
   
   for i = 1:length(g)
       xData = [xData(2:end); g(i).signals.x];
       yData = [yData(2:end); g(i).signals.y];
       set(h, 'XData', xData, 'YData', yData);
   end
   
   set(hToc, 'YData', tocVec);
   
   if ~isempty(g)
       drawnow;
   end
   
   pause(0.001);
   
   if ~ishandle(1);
       udpMexReceiver('stop');
   end
end
