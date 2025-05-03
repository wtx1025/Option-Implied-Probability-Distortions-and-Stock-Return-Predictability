function iv = impliedVol(S, K, r, T, marketPrice, optionType)
    % impl_vol_bfgs - 使用 BFGS 方法計算 Black-Scholes 模型的隱含波動率
    % 
    % 調用方式:
    %   iv = impl_vol_bfgs(S, K, r, T, marketPrice, optionType)
    % 
    % 輸入:
    %   S            - 標的資產現價
    %   K            - 行權價
    %   r            - 無風險利率 (年化)
    %   T            - 剩餘到期時間 (年)
    %   marketPrice  - 市場價格
    %   optionType   - 選擇權類型 ('C' 或 'P')
    % 
    % 輸出:
    %   iv           - 隱含波動率

    % 定義初始猜測值和邊界條件
    initialGuess = 0.2; % 初始猜測波動率
    lowerBound = 1e-6;   % 最低波動率 (避免數值錯誤)
    upperBound = 5;    % 假設最大波動率

    % 使用 fminunc (BFGS 方法)
    options = optimoptions('fminunc', 'Algorithm', 'quasi-newton', 'Display', 'off');
    objFun = @(sigma) (calculateError(S, K, r, T, marketPrice, sigma, optionType));

    % 最小化目標函數
    [iv, ~, exitFlag] = fminunc(objFun, initialGuess, options);

    % 如果結果不收斂，返回 NaN
    if exitFlag <= 0 || iv < lowerBound || iv > upperBound 
        iv = NaN;
    end

    function error = calculateError(S, K, r, T, marketPrice, sigma, optionType)
        % 計算 Black-Scholes 理論價格
        d1 = (log(S / K) + (r + 0.5 * sigma^2) * T) / (sigma * sqrt(T));
        d2 = d1 - sigma * sqrt(T);

        if strcmp(optionType, 'C')
            bsPrice = S * normcdf(d1) - K * exp(-r * T) * normcdf(d2);
        elseif strcmp(optionType, 'P')
            bsPrice = K * exp(-r * T) * normcdf(-d2) - S * normcdf(-d1);
        else
            error('Invalid option type. Use ''C'' for call or ''P'' for put.');
        end

        % 計算理論價格與市場價格的平方差
        error = (bsPrice - marketPrice)^2;
    end
end