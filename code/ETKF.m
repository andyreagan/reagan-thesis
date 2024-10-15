function X_a = ETKF(X_f,y_o,H,R,delta,varargin)

% ETKF.m
%
% Ensemble Transform Kalman Filter: compute the new analysis
% 
% INPUTS
%  X_f:     the whole forecast, columns are model state
%
% OUTPUTS
%  X_a:     the analysis matrix, columns are model state analysis
%
% written by Andy Reagan
% 2013-10-18

silent = 0;

i=1; 
while i<=length(varargin), 
  argok = 1; 
  if ischar(varargin{i}), 
    switch varargin{i},
        case 'silent',       silent  = 1;
        otherwise, argok=0; 
    end
  end
  if ~argok, 
    fprintf('invalid argument %s\n',varargin{1})
  end
  i = i+1; 
end

N = length(X_f(1,:));

%% let x_f now be the average
x_f = mean(X_f,2);

X_f_diff = X_f - repmat(x_f,1,N);

%% multiplicative inflation
X_f_diff = sqrt(1+delta).*X_f_diff;

p_f = 1/(N-1)*(X_f_diff*X_f_diff');

K = (p_f*H')/(R+H*p_f*H');

d = y_o - H*x_f;

x_a = x_f + K*d;

%% perform the transform
%% it is (from the literature)
%% absolutely necessary to perform this inversion
p_a = inv((N-1)*eye(N)+(H*X_f_diff)'/(R)*(H*X_f_diff));

T = sqrtm((N-1)*p_a);

X_a_diff = X_f_diff*T;

%% now compute the analysis for each ensemble member
X_a=repmat(x_a,1,N) + X_a_diff;

if ~silent
  fprintf('K is\n')
  disp(K);
  fprintf('p_f is\n')
  disp(p_f);
end


