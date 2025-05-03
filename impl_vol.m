function iv = impl_vol(S, K, r, T, marketPrice, optionType)
    % impl_vol - 計算 Black-Scholes 模型的隱含波動率
    % 
    % 調用方式:
    %   iv = impl_vol(S, K, r, T, marketPrice, optionType)
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

    % 初始猜測波動率
    sigma = 0.2; % 初始猜測值
    tol = 1e-4;  % 收斂容差
    maxIter = 100; % 最大迭代次數
    
    for iter = 1:maxIter
        % 計算 d1 和 d2
        d1 = (log(S / K) + (r + 0.5 * sigma^2) * T) / (sigma * sqrt(T));
        d2 = d1 - sigma * sqrt(T);
        
        % 計算 Black-Scholes 理論價格
        if strcmp(optionType, 'C')
            bsPrice = S * normcdf(d1) - K * exp(-r * T) * normcdf(d2);
        elseif strcmp(optionType, 'P')
            bsPrice = K * exp(-r * T) * normcdf(-d2) - S * normcdf(-d1);
        else
            error('Invalid option type. Use ''C'' for call or ''P'' for put.');
        end
        
        % 計算 Vega
        vega = S * normpdf(d1) * sqrt(T);
        
        % 計算誤差
        diff = bsPrice - marketPrice;
        
        % 判斷收斂條件
        if abs(diff) < tol
            iv = sigma;
            return;
        end
        
        % 更新波動率 (Newton-Raphson 方法)
        sigma = sigma - diff / vega;
        
        % 確保 sigma 非負
        if sigma <= 0
            sigma = 1e-6; % 避免負值
        end
    end
    
    % 若未收斂，返回 NaN 並給出警告
    %warning('Implied volatility did not converge.');
    iv = sigma;
end

