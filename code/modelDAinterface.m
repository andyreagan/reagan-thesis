function [x_f_all,x_a_all] = modelDAinterface(modelname,filter,y,y_t,H,R,window,delta,mu,varargin)
% modelDAinterface.m
%
% written by Andy Reagan
% 2013-10-14
%
% combine abstract model class and DA code for experimentation
% things should be general enough for this to work both lorenz and foam
%
% INPUT:
%   modelname       the model: try either 'lorenz63' or 'OpenFOAM'
%   filter          filtering algorithm: 'EKF' or 'EnKF' for starters
%   y               matrix of observations [y_0,y_1,...,y_N]
%   y_t             vector of observation time [0,1,2,...,100]
%   H               observation operator
%   R               obs error covariance (block-diagonal,sym)
%   window          length of assimilation window
%   delta           multiplicative covariance influation
%   mu              additive covariance inflation
% (optional, see more below)
%   writecontrol,t  specify density of forecast output:
%    		    default is only at the windows
%                       
%   numens,N        specify number of ensemble members
%                   e.g. 'numens',20
%                   default is 10
%
%   params,paramCell
%                   set the model parameters for choosing
%
% OUTPUT:
%   x_f_all       matrix store of the forecasts
%   x_a_all       matrix store of the analyses

%% defaults
save_int = window; % output times
N = 10; % number of ens members
modelnamestr = func2str(modelname);
silent = 1;
setparams = 0;
np = 1;
seed = sum(100*clock);

%% parse input
for i=1:2:nargin-9
    switch varargin{i}
        case 'writecontrol'
            save_int = varargin{i+1};
        case 'numens'
            N =   varargin{i+1};
        case 'params'
            setparams = 1; params = varargin{i+1};
        case 'silent'
            silent = varargin{i+1};
        case 'OFmodel'
            OFCase = varargin{i+1};
        case 'randseed'
            seed = varargin{i+1};
        case 'climcov' % pass a climatological covariance for 3DVar
            load(varargin{i+1});
    end
end

%% reset the random seed
rng('shuffle','twister'); %% for 2013a
%% RandStream.setDefaultStream(RandStream.create('mt19937ar','seed',seed)); %% for 2010b
randStr = sprintf('%06d',randi(1000000,1));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% INITIALIZE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

switch filter
    case 'EKF'
        %% set up for having a EKF
        model = modelname();
        if setparams
            model.params = params;
        end
        model.init(sprintf('%s/model',randStr));
        model.window = window;
        x_a = model.x;
        cov_init_max = 10; % start the covariance large, it will calm down
        % passing this by value instead of via disk
        % save('P.mat',cov_init_max*eye(model.dim));
        fprintf('model dimension in modelDAinterface line 84 is %g\n',model.dim);
        p_a = cov_init_max*eye(model.dim);
        % disp(size(p_a));
        % disp(model)
        % make the dimension local
        dim = model.dim;
        
    case {'direct','none','3dvar'}
        %% set up for having no DA, either direct input or none
        model = modelname();
        if setparams
            model.params = params;
        end
        model.init(sprintf('%s/model',randStr));
        model.window = window;
        dim = model.dim*np;
        x_a = model.x;
        
    case {'EnKF','ETKF','EnSRF'}
        %% set up ensemble if we're doing an ensemble filter
        ensemble = cell(N,1);
        ensemble{1} = modelname();
        if setparams
            ensemble{1}.params = params;
        end
        ensemble{1}.init(sprintf('%s/ens%02d',randStr,1));
        % start the first model
        ensemble{1}.window = window;
        dim = ensemble{1}.dim*np;
        
        X_f = ones(dim,N);
        X_a = ones(dim,N);
        X_a(:,1) = ensemble{1}.x;
        % make the rest of the ensemble
        for i=2:N
            ensemble{i} = modelname();
            if setparams
                ensemble{i}.params = params;
            end
            ensemble{i}.init(sprintf('%s/ens%02d',randStr,i));
            ensemble{i}.window = window;
            X_a(:,i) = ensemble{i}.x;
        end % ensemble initialization
end %% switch

num_windows = length(y(1,:));
x_f_all = ones(dim,num_windows);
x_a_all = ones(dim,num_windows);


%% predict the given timeseries
i=0;
for time=0:window:max(y_t)
    i=i+1; %% loop counter
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% FORECAST: RUN MODEL
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    switch filter
        case 'EKF'
            %% set the IC
            model.x = x_a;
            %% run both models
            model.runTLM(p_a);
            model.run();
            %% store the forecast
            x_f_all(:,i) = model.x;
        case {'direct','none','3dvar'}
            %% run the forward model for no DA
            %% set the IC
            model.x = x_a;
            %% run model
            model.run();
            %% store the forecast
            x_f_all(:,i) = model.x;
        case {'EnKF','EnSRF','ETKF'}
            %% run the ens if we're doing the EnKF
            %% run the whole ensemble forward
            for j=1:N
                % set the IC
                ensemble{j}.x = X_a(:,j);
                % run
                ensemble{j}.run();
                % record the model output from run
                X_f(:,j) = ensemble{j}.x;
            end
            %% store the forecast
            x_f_all(:,i) = mean(X_f,2);
    end %% switch
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% ASSIMILATE
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    switch filter
        case 'EKF'
            %% pre-analysis multiplicative inflation
            model.p_f = (1+delta).*model.p_f;
            [x_a,p_a] = EKF(model.x,y(:,i),H,R,model.p_f,'silent');
            %% post analysis additive inflation
            p_a = p_a + mu*diag(rand(size(x_a)));
            x_a_all(:,i) = x_a;
            
        case 'direct'
            x_a = direct(x_f_all(:,i),y(:,i),H);
            x_a_all(:,i) = x_a;
            
        case 'none'
            x_a = none(x_f_all(:,i));
            x_a_all(:,i) = x_a;
            
        case '3dvar'
            x_a = threedvar(x_f_all(:,i),y(:,i),H,R,B,'silent');
            x_a_all(:,i) = x_a;
            
        case 'EnKF'
            X_a = EnKF(X_f,y(:,i),H,R,delta,'silent');
            %% post analysis additive inflation
            X_a = X_a+mu*rand(size(X_a));
            x_a_all(:,i) = mean(X_a,2);
            
        case 'EnSRF'
            X_a = EnSRF(X_f,y(:,i),H,R,delta,'silent');
            %% post analysis additive inflation
            X_a = X_a+mu*rand(size(X_a));
            x_a_all(:,i) = mean(X_a,2);
                     
        case 'ETKF'
            X_a = ETKF(X_f,y(:,i),H,R,delta,'silent');
            %% post analysis additive inflation
            X_a = X_a+mu*rand(size(X_a));
            x_a_all(:,i) = mean(X_a,2);

    end %% switch
    %% wash, rinse, repeat

end %% for loop
end %% function




