%==========================================================================
%
% ABM7  Adams-Bashforth-Moulton 7th-order method.
%
%   [t,y] = ABM7(f,[t0,tf],y0,h)
%   [t,y] = ABM7(f,{t0,C},y0,h)
%   [t,y] = ABM7(__,wb)
%
% See also ABM2, ABM3, ABM4, ABM5, ABM6, ABM8.
%
% Copyright © 2021 Tamas Kis
% Last Update: 2022-04-16
% Website: https://tamaskis.github.io
% Contact: tamas.a.kis@outlook.com
%
% TOOLBOX DOCUMENTATION:
% https://tamaskis.github.io/ODE_Solver_Toolbox-MATLAB/
%
% TECHNICAL DOCUMENTATION:
% https://tamaskis.github.io/documentation/Fixed_Step_ODE_Solvers.pdf
%
%--------------------------------------------------------------------------
%
% ------
% INPUT:
% ------
%   f       - (1×1 function_handle) dy/dt = f(t,y) --> multivariate, 
%             vector-valued function (f : ℝ×ℝᵖ → ℝᵖ) defining ODE
%   I       - defines interval over which to solve the ODE, 2 options:
%               --> [t0,tf] - (1×2 double) initial and final times
%               --> {t0,C}  - (1×2 cell) initial time, t₀, and function 
%                             handle for condition function, C(t,y) 
%                             (C : ℝ×ℝᵖ → 𝔹)
%   y0      - (p×1 double) initial condition, y₀ = y(t₀)
%   h       - (1×1 double) step size
%   wb      - (1×1 logical or char) (OPTIONAL) waitbar parameters
%               --> input as "true" if you want waitbar with default 
%                   message displayed
%               --> input as a char array storing a message if you want a
%                   custom message displayed on the waitbar
%
% -------
% OUTPUT:
% -------
%   t       - ((N+1)×1 double) time vector
%   y       - ((N+1)×p double) matrix storing time history of state vector
%
% -----
% NOTE:
% -----
%   --> p = dimension of state vector (for the scalar case, p = 1)
%   --> m = order of multistep method
%   --> N+1 = length of time vector
%   --> The ith row of "y" is the TRANSPOSE of the state vector (i.e. the
%       solution corresponding to the ith time in "t"). This convention is
%       chosen to match the convention used by MATLAB's ODE suite.
%
%==========================================================================
function [t,y] = ABM7(f,I,y0,h,wb)
    
    % ------------------------------
    % Order of the multistep method.
    % ------------------------------
    
    m = 7;
    
    % -------------------
    % Setting up waitbar.
    % -------------------

    % determines if waitbar is on or off
    if (nargin < 5) || (islogical(wb) && ~wb)
        display_waitbar = false;
    else
        display_waitbar = true;
    end

    % sets the waitbar message (defaults to 'Solving ODE...')
    if display_waitbar
        if ischar(wb)
            msg = wb;
        else
            msg = 'Solving ODE...';
        end
    end

    % initialize cutoff proportion needed to trigger waitbar update to 0.1
    if display_waitbar, prop = 0.1; end
    
    % ---------------------------------------
    % Determines which implementation to use.
    % ---------------------------------------
    
    if iscell(I)
        t0 = I{1};
        C = I{2};
        time_detection_implementation = false;
    else
        t0 = I(1);
        tf = I(2);
        time_detection_implementation = true;
    end
        
    % --------------------------------------------------------
    % Time detection implementation (solves until final time).
    % --------------------------------------------------------
    
    if time_detection_implementation

        % initializes the waitbar
        if display_waitbar, wb = waitbar(0,msg); end

        % makes step size negative if t0 > tf
        if t0 > tf
            h = -h;
        end
        
        % number of subintervals between sample times
        N = ceil((tf-t0)/h);
        
        % last element of the time vector
        tN = t0+N*h;
        
        % defines time vector, preallocates solution matrix, and 
        % preallocates matrix to store previous m function evaluations
        t = (t0:h:tN)';
        y = zeros(length(y0),length(t));
        fm = zeros(length(y0),m);

        % stores initial condition in solution matrix
        y(:,1) = y0;
        
        % propagating state vector using RK4 for first "m" sample times
        for n = 1:m

            % current sample time and state vector
            tn = t(n);
            yn = y(:,n);

            % k terms
            k1 = f(tn,yn);
            k2 = f(tn+h/2,yn+h*k1/2);
            k3 = f(tn+h/2,yn+h*k2/2);
            k4 = f(tn+h,yn+h*k3);

            % state vector propagated to next sample time
            y(:,n+1) = yn+(h/6)*(k1+2*k2+2*k3+k4);
            
            % updates waitbar
            if display_waitbar, prop = update_waitbar(n,N,wb,prop); end

        end
        
        % stores function evaluations for first m sample times
        for n = 1:m
            fm(:,n) = f(t(n),y(:,n));
        end
        
        % propagating state vector using ABM7
        for n = (m+1):N
            
            % updates stored function evaluations
            fm = [fm(:,2:end),f(t(n),y(:,n))];
            
            % predictor step
            yp = y(:,n)+(h/60480)*(198721*fm(:,m)-447288*fm(:,m-1)+...
                705549*fm(:,m-2)-688256*fm(:,m-3)+407139*fm(:,m-4)-...
                134472*fm(:,m-5)+19087*fm(:,m-6));
            
            % corrector step (state vector propagated to next sample time)
            y(:,n+1) = y(:,n)+(h/60480)*(19087*f(t(n+1),yp)+65112*...
                fm(:,m)-46461*fm(:,m-1)+37504*fm(:,m-2)-20211*fm(:,m-...
                3)+6312*fm(:,m-4)-863*fm(:,m-5));
            
            % updates waitbar
            if display_waitbar, prop = update_waitbar(n,N,wb,prop); end
            
        end
        
        % linearly interpolates for solution at tf
        y(:,N+1) = y(:,N)+((y(:,N+1)-y(:,N))/(t(N+1)-t(N)))*(tf-t(N));
        
        % replaces last element of "t" with tf
        t(N+1) = tf;
        
        % closes waitbar
        if display_waitbar, close(wb); end
    
    % ---------------------------------------------------------------------
    % Event detection implementation (solves while condition is satisfied).
    % ---------------------------------------------------------------------
    
    else

        % preallocates time vector, solution matrix, and array to store 
        % previous m function evaluations
        t = zeros(10000,1);
        y = zeros(length(y0),length(t));
        fm = zeros(length(y0),m);
        
        % time vector for first m sample times
        t(1:m) = (t0:h:(t0+(m-1)*h))';
        
        % stores initial condition in solution matrix
        t(1) = t0;
        y(:,1) = y0;
        
        % propagating state vector using RK4 for first m sample times
        for n = 1:m

            % current sample time and state vector
            tn = t(n);
            yn = y(:,n);

            % k terms
            k1 = f(tn,yn);
            k2 = f(tn+h/2,yn+k1*h/2);
            k3 = f(tn+h/2,yn+k2*h/2);
            k4 = f(tn+h,yn+k3*h);

            % state vector propagated to next sample time
            y(:,n+1) = yn+(h/6)*(k1+2*k2+2*k3+k4);

        end

        % stores function evaluations for first m sample times
        for n = 1:m
            fm(:,n) = f(t(n),y(:,n));
        end
        
        % state vector propagation while condition is satisfied
        n = m;
        while C(t(n),y(:,n))
        
            % expands t and y if needed
            if (n+1) > length(t)
                [t,y] = expand_solution_arrays(t,y);
            end
            
            % updates stored function evaluations
            fm = [fm(:,2:end),f(t(n),y(:,n))];
            
            % predictor step
            yp = y(:,n)+(h/60480)*(198721*fm(:,m)-447288*fm(:,m-1)+...
                705549*fm(:,m-2)-688256*fm(:,m-3)+407139*fm(:,m-4)-...
                134472*fm(:,m-5)+19087*fm(:,m-6));
            
            % corrector step (state vector propagated to next sample time)
            y(:,n+1) = y(:,n)+(h/60480)*(19087*f(t(n+1),yp)+65112*...
                fm(:,m)-46461*fm(:,m-1)+37504*fm(:,m-2)-20211*fm(:,m-...
                3)+6312*fm(:,m-4)-863*fm(:,m-5));
            
            % increments time and loop index
            t(n+1) = t(n)+h;
            n = n+1;

        end

        % trims arrays
        y = y(:,1:(n-1));
        t = t(1:(n-1));
        
    end
    
    % transposes solution matrix so it is returned in "standard form"
    y = y';
    
    % -------------
    % Subfunctions.
    % -------------
    
    %----------------------------------------------------------------------
    % expand_solution_arrays  Expands the arrays storing the ODE solution. 
    % This function is used to preallocate more space for the solution 
    % arrays (i.e. the time vector and the solution matrix) once they have 
    % become full.
    %----------------------------------------------------------------------
    %
    % INPUT:
    %   t       - ((N+1)×1 double) time vector
    %  	y       - (p×(N+1) double) solution matrix
    %
    % OUTPUT:
    %   t_new   - (2(N+1)×1 double) expanded time vector
    %  	y_new   - (p×2(N+1) double) expanded solution matrix
    %
    % NOTE:
    %   --> p = dimension of state vector (for the scalar case, p = 1) 
    %   --> N+1 = original length of time vector
    %
    %----------------------------------------------------------------------
    function [t_new,y_new] = expand_solution_arrays(t,y)
        t_new = [t;zeros(length(t),1)];
        y_new = [y,zeros(size(y,1),length(t))];
    end

    %----------------------------------------------------------------------
    % update_waitbar  Updates the waitbar.
    %----------------------------------------------------------------------
    %
    % INPUT:
    %   n       - (1×1 double) current sample number (i.e. iteration)
    %  	N       - (1×1 double) total number of samples (i.e. iterations)
    %   wb      - (1×1 Figure) waitbar
    %   prop    - (1×1 double) cutoff proportion to trigger waitbar update
    %
    % OUTPUT:
    %   prop    - (1×1 double) cutoff proportion to trigger waitbar update
    %
    % NOTE:
    %   --> "prop" is an integer multiple of 0.1 so that the waitbar is
    %       only updated after every additional 10% of progress.
    %
    %----------------------------------------------------------------------
    function prop = update_waitbar(n,N,wb,prop)
        
        % only updates waitbar if current proportion exceeds cutoff prop.
        if n/N > prop
            
            % updates waitbar
            waitbar(n/N,wb);
            
            % updates cutoff proportion needed to trigger waitbar update
            prop = prop+0.1;
            
        end
        
    end

end