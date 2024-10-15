classdef OpenFOAM<handle
    %OpenFOAM: class for an OpenFOAM run
    %   Goal is to implement a class for which MATLAB can
    %   control and run an OpenFOAM instance
    %
    %   USAGE:
    %       -initialize an OpenFOAM directory, read to be run, at 'testCase'
    %        ens1 = OpenFOAM('2D-foamLabBase-mesh40000');
    %        ens1.init('testCase');
    %       -run OpenFOAM on this case
    %        ens1.run();
    
    properties
        %% basics
        x
        dim
        tstep = 1;
        time = 0;
        windowLen = 20;
        params
        
        foamLab = '/users/a/r/areagan/work/2013/data-assimilation/OpenFOAM/foamLab.sh';
        TIME=0;
        ETIME=20;
        DIR='testCase'
        FLUX=10000; 
        BCbottom = '340';
        BCtop = '290';
        BC = 'fixedValue';
        TURB = 'off';
        BASE = '2D-foamLabSmall';
        TURBMODEL = 'kEpsilon';
        T
        U
        p
        p_rgh
        Tstep = 1;
        WRITEp = 6;
        VALUE = [];
        np = 6;
    end %% properties
    
    methods
        function self = OpenFOAM(varargin)
            %% intialize the class
            if nargin > 0
                self.BASE = varargin{1};
            end
            switch self.BASE
                case '2D-foamLabSmall'
                    self.dim = 600;
                case '2D-foamLabBase'
                    self.dim = 36000;
                case '2D-foamLabBase-mesh40000'
                    self.dim = 40000;
                otherwise
                    warning('chosen case does not have a predifined dimension. edit class to include it');
            end
            self.T = 300*ones(self.dim,1);
            self.U = zeros(self.dim,3); %%1e-6*ones(40832,3);
            self.p = zeros(self.dim,1); %%1e-6*ones(40832,1);
            self.p_rgh = zeros(self.dim,1); %%1e-6*ones(40832,1);
            self.x = ones(self.dim*self.np,1);
            self.vectorize('in');
        end %% constructor
        function init(self,varargin)
            if nargin > 1
                self.DIR = varargin{1};
            end
            %% intialize a a clean dir
            command = sprintf('%s -i -d %s -B %s -h %s -g %s -b %s -q %s -Q %s',self.foamLab,self.DIR,self.BASE,self.BCtop,self.BCbottom,self.BC,self.TURB,self.TURBMODEL);
            fprintf('%s\n',command);
            system(command);
        end %% init
        function read(self,time,varargin)
            %% read in a specific time variable
            %% first: have foamLab write the csv
            caseDir = sprintf('/users/a/r/areagan/OpenFOAM/areagan-2.2.1/run/%s',self.DIR);
            system(sprintf('%s -r %g -d %s -D %d',self.foamLab,time,caseDir,self.dim));
            self.T = csvread(sprintf('%s/%g/T.csv',caseDir,time));
            self.U = csvread(sprintf('%s/%g/U.csv',caseDir,time));
            self.p = csvread(sprintf('%s/%g/p.csv',caseDir,time));
            self.p_rgh = csvread(sprintf('%s/%g/p_rgh.csv',caseDir,time));
            self.vectorize('in');
        end %% read
        function write(self,time,varargin)
            %% write out variable
            self.vectorize('out');
            caseDir = sprintf('/users/a/r/areagan/OpenFOAM/areagan-2.2.1/run/%s',self.DIR);
            csvwrite(sprintf('%s/%g/T.csv',caseDir,time),self.T);
            csvwrite(sprintf('%s/%g/U.csv',caseDir,time),self.U);
            csvwrite(sprintf('%s/%g/p.csv',caseDir,time),self.p);
            csvwrite(sprintf('%s/%g/p_rgh.csv',caseDir,time),self.p_rgh);
            system(sprintf('%s -W %g -d %s',self.foamLab,time,caseDir));
        end %% write
         function run(self,varargin)
            caseDir = sprintf('/users/a/r/areagan/OpenFOAM/areagan-2.2.1/run/%s',self.DIR);
            
            %% write out the current x before running
            self.write(self.time)
            
            tmpcommand = sprintf('%s -x -d %s -t %g -e %g -l %g -w %g -c %g -B %s -D %d',self.foamLab,caseDir,self.time,self.time+self.windowLen,self.tstep,self.WRITEp,self.windowLen,self.BASE,self.dim);
            fprintf('%s\n',tmpcommand);
            system(tmpcommand);

            %% update time
            self.time = self.time+self.windowLen;
            self.read(self.time);
        end %% run
        function vectorize(self,direction)
            %% self.np is the number of variables used, order a permutation on their storage
	    switch self.np
                case {1,6}
		     order = 0:5;
		case 3 
		     order = [0 0 1 2 0 0];
	    end
            switch direction
                case 'in' %% into the datavec
                    self.x((1:self.np:(self.dim*self.np+1-self.np))+order(1)) = self.T;
                    self.x((1:self.np:(self.dim*self.np+1-self.np))+order(2)) = self.U(:,1);
                    self.x((1:self.np:(self.dim*self.np+1-self.np))+order(3)) = self.U(:,2);
                    self.x((1:self.np:(self.dim*self.np+1-self.np))+order(4)) = self.U(:,3);
                    self.x((1:self.np:(self.dim*self.np+1-self.np))+order(5)) = self.p;
                    self.x((1:self.np:(self.dim*self.np+1-self.np))+order(6)) = self.p_rgh;
                case 'out' %% out of x into T,U,p,p_rgh
                    self.T = self.x((1:self.np:(self.dim*self.np+1-self.np))+order(1));
                    self.U(:,1) = self.x((1:self.np:self.dim*self.np)+order(2));
                    self.U(:,2) = self.x((1:self.np:(self.dim*self.np+1-self.np))+order(3));
                    self.U(:,3) = self.x((1:self.np:(self.dim*self.np+1-self.np))+order(4));
                    self.p = self.x((1:self.np:self.dim*self.np)+order(5));
                    self.p_rgh = self.x((1:self.np:self.dim*self.np)+order(6));
            end %% switch
        end %% vectorize
        function destruct(self)
            %% destroy the folder, for sanity's sake
            system(sprintf('\\rm -rf /users/a/r/areagan/OpenFOAM/areagan-2.2.1/run/%s',self.DIR));
        end
    end %% methods
end %% classdef






