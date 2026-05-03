% Plot a sine curve and save both MATLAB FIG and PNG outputs.

x = linspace(0, 2*pi, 1000);
y = sin(x);

fig = figure('Color', 'w');
plot(x, y, 'b-', 'LineWidth', 2);
grid on;
xlabel('x');
ylabel('sin(x)');
title('Sine Curve');

savefig(fig, 'sine_curve.fig');
exportgraphics(fig, 'sine_curve.png', 'Resolution', 200);
% close(fig);
