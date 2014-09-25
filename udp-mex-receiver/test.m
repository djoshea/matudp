
udpMexReceiver('start');

figure(1), clf, set(1, 'Color', 'w');

hHand = plot(0,0, 'r.', 'MarkerSize', 5);
hold on
hTarget = plot(0,0, 'gx', 'MarkerSize', 15);


xlim([-100 100]);
ylim([-100 100]);
xlabel('x');
ylabel('y');

while(1)
    z = udpMexReceiver('pollGroups');
   
    [tf idx] = ismember('handInfo', {z.name});
    if ~tf
        handInfo = z(idx).signals;
        set(hHand, 'XData', handInfo.handX,'YData', sig.handY);
    end

    [tf idx] = ismember('param', {z.name});
    if ~tf
        param = z(idx).signals;
        set(hTarget, 'XData', param.targetX,'YData', param.targetY);
    end
    drawnow
end
