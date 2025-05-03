clear;
file1 = "C:\Users\王亭烜\Desktop\Thesis\Data\data1221\EstimatedStates.csv"; 
data1 = readtable(file1);
file2 = "C:\Users\王亭烜\Desktop\Thesis\Data\data1221\EstimatedStates2.csv"; 
data2 = readtable(file2);

figure;
hold on;
plot(data1.Date, data1.EstimatedState, '-o', 'DisplayName', 'File 1', 'LineWidth', 1.5);
plot(data2.Date, data2.EstimatedState, '-x', 'DisplayName', 'File 2', 'LineWidth', 1.5);
hold off;

grid on;
xlabel('Date');
ylabel('Estimated State');
title('Comparison of Estimated State Between Two Files');
legend('show', 'Location', 'best');
datetick('x', 'yyyy-mm', 'keeplimits');
xtickangle(45);
