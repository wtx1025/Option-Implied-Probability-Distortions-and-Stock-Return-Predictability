clear; 
estimated_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\EstimatedStates2.csv");
gw_data = readtable("C:\Users\王亭烜\Downloads\return prediction(1).csv");
sp_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\sp_raw_data.csv");
rf_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\rf_raw_data.xlsx");

% data cleaning
sp_data.YearMonth = dateshift(sp_data.caldt, 'start', 'month'); 
[~, lastDayIdx] = unique(sp_data.YearMonth, 'last'); 
monthlyLastData = sp_data(lastDayIdx, :); 
monthlyLastData.MonthlyReturn = [NaN; diff(log(monthlyLastData.spindx))];

rf_data.observation_date = datetime(rf_data.observation_date);
monthlyLastData = innerjoin(monthlyLastData, rf_data, 'LeftKeys', 'caldt', 'RightKeys', 'observation_date');
monthlyLastData.ExcessReturn = monthlyLastData.MonthlyReturn - monthlyLastData.DTB3 / (100*12); 

startDate = datetime(2010, 6, 1);
endDate = datetime(2023, 8, 31);
estimated_data = estimated_data(estimated_data.Date >= startDate & estimated_data.Date <= endDate, :);
monthlyLastData = monthlyLastData(monthlyLastData.caldt >= startDate & monthlyLastData.caldt <= endDate, :);
if isnumeric(gw_data.yyyymm)
    gw_data.yyyymm = datetime(num2str(gw_data.yyyymm), 'InputFormat', 'yyyyMM'); 
end 
gw_data = gw_data(gw_data.yyyymm >= startDate & gw_data.yyyymm <= endDate, :);

mergedData = [monthlyLastData, estimated_data(:, {'Alpha'}), gw_data];
mergedData = mergedData(:, {'caldt', 'spindx', 'ExcessReturn', 'Alpha', 'b_m', 'tbl', 'lty', 'ntis', 'infl',...
    'ltr', 'svar', 'log_dp', 'log_dy', 'log_ep', 'log_de', 'tms', 'dfy', 'dfs'}); 

%% Generate predeiction for all the predictors and benchmark (5 methods)
mergedData.BenchmarkPrediction = NaN(height(mergedData), 1);
for i = 1:height(mergedData)
    targetDate = mergedData.caldt(i);
    idx = find(mergedData.caldt < targetDate);
    if length(idx) >= 36
        pastReturns = mergedData.ExcessReturn(idx);
        mergedData.BenchmarkPrediction(i) = mean(pastReturns, 'omitnan'); 
    end 
end 

benchmarkErrors = mergedData.ExcessReturn - mergedData.BenchmarkPrediction; 
benchmark_mspe = mean(benchmarkErrors .^ 2, 'omitnan');

selectedVars = {'b_m', 'tbl', 'lty', 'ntis', 'infl',...
    'ltr', 'svar', 'log_dp', 'log_dy', 'log_ep', 'log_de', 'tms', 'dfy', 'dfs'};

n = 36;
for i = 1:length(selectedVars)
    varName = selectedVars{i};
    newVarName = strcat(varName, '_predict'); 
    mergedData.(newVarName) = NaN(height(mergedData), 1);
    for t = n:height(mergedData)-1
        X = mergedData{1:t-1, {'Alpha', varName}}; 
        Y = mergedData.ExcessReturn(2:t);
        X_mean = mean(X, 'omitnan');
        X_std = std(X, 'omitnan'); 
        X_standardized = (X - X_mean) ./ X_std; 
        X_with_intercept = [ones(size(X_standardized, 1), 1), X_standardized];
        b = regress(Y, X_with_intercept);
        predictor = (mergedData{t, {'Alpha', varName}} - X_mean) ./ X_std; 
        predictor_with_intercept = [1, predictor];
        mergedData.(newVarName)(t+1) = predictor_with_intercept * b; 
    end 
end 

% Equal-weighted combination 
mergedData.EWC = 1/14 * (mergedData.b_m_predict + mergedData.tbl_predict + mergedData.lty_predict +...
    mergedData.ntis_predict + mergedData.infl_predict + mergedData.ltr_predict + mergedData.svar_predict +...
    mergedData.log_dp_predict + mergedData.log_dy_predict + mergedData.log_ep_predict +...
    mergedData.log_de_predict + mergedData.tms_predict + mergedData.dfy_predict + mergedData.dfs_predict); 

EWC_error = mergedData.EWC - mergedData.ExcessReturn;
EWC_mspe = mean(EWC_error .^ 2, 'omitnan');
EWC_r2 = 1 - EWC_mspe / benchmark_mspe;

% Trimmed mean combination 
predictions = {'b_m_predict', 'tbl_predict', 'lty_predict', 'ntis_predict', 'infl_predict',...
    'ltr_predict', 'svar_predict', 'log_dp_predict', 'log_dy_predict', 'log_ep_predict',...
    'log_de_predict', 'tms_predict', 'dfy_predict', 'dfs_predict'};
for i = 1:length(predictions)
    varName = predictions{i};
    newVarName = strcat(varName, '_trimmed');
    mergedData.(newVarName) = NaN(height(mergedData), 1);
end 

for t = n:height(mergedData)-1
    pre_mspe = NaN(1, length(predictions));
    for i = 1:length(predictions)
        varName = predictions{i};
        mspe = (mergedData.(varName)(t) - mergedData.ExcessReturn(t))^2;
        pre_mspe(i) = mspe;
    end 

    maximum = max(pre_mspe);
    for m = 1:length(predictions)
        varName = predictions{m};
        newVarName = strcat(varName, '_trimmed');
        mspe = (mergedData.(varName)(t) - mergedData.ExcessReturn(t))^2;
        if mspe == maximum
            mergedData.(newVarName)(t+1) = 0;
        else
            mergedData.(newVarName)(t+1) = 1;
        end 
    end 
end 

mergedData.TMC = zeros(height(mergedData), 1);
for i = 1:length(predictions)
    varName1 = predictions{i};
    varName2 = strcat(varName, '_trimmed');
    mergedData.TMC = mergedData.TMC + 1/13 .* mergedData.(varName1) .* mergedData.(varName2); 
end 

TMC_error = mergedData.TMC - mergedData.ExcessReturn;
TMC_mspe = mean(TMC_error .^ 2, 'omitnan');
TMC_r2 = 1 - TMC_mspe / benchmark_mspe; 

outputFilePath = "C:\\Users\\王亭烜\\Desktop\\Thesis\\Data\\data1221\\test2.csv";
writetable(mergedData, outputFilePath);
fprintf('Successfully saved monthly data to %s\n', outputFilePath);