clear; 
warning('off','all')

COHORT = 'ROCKLAND'; 
COHORTDIR = '/Users/sorooshafyouni/Home/GitClone/FILM2/Externals/ROCKLAND/';
pwdmethod = 'ACFadj'; %ACF AR-YW AR-W ARMAHR
Mord      = 30; 
lFWHM     = 5;
SubID     = 'A00028858';
SesID     = 'DS2'; 
TR        = 0.645;
EDtype    = 'ER'; % boxcar
%TempTreMethod = 'spline'; 
%NumTmpTrend   = 3;

TempTreMethod = 'hpf'; 
NumTmpTrend   = [];


% What is flowing in from the cluster:
disp('From the cluster ======================')
disp(['SubID: ' SubID])
disp(['SesID: ' SesID])
disp(['TR: ' num2str(TR)])
disp(['ARmethod: ' pwdmethod])
disp(['AR order:' num2str(Mord)])
disp(['lFWHM: ' num2str(lFWHM)])
%disp(['COHORT directory:' COHORTDIR])





SaveImagesFlag      = 1; 
SaveMatFileFlag     = 1; 
DoDetrendingPrior   = 0; 
MParamNum           = 24;
gsrflag             = 1;
icaclean            = 0;

disp('=======================================')

PATH2AUX='/Users/sorooshafyouni/Home/GitClone/FILM2';
addpath([PATH2AUX '/utils/Trend'])
addpath('/Users/sorooshafyouni/Home/matlab/spm12')
addpath([PATH2AUX '/utils/AR_YW'])
addpath([PATH2AUX '/utils/ARMA_HR'])
addpath([PATH2AUX '/mis'])


disp('=====SET UP PATHS =============================')
%Raw Images (MMP feat output)
%Raw Images (MMP feat output)
Path2ImgRaw = [COHORTDIR '/R_mpp/sub-' SubID '/ses-' SesID];
if strcmpi(COHORT,'ROCKLAND')
    Path2ImgDir = [Path2ImgRaw '/sub-' SubID '_ses-' SesID '_task-rest_acq-' num2str(TR*1000) '_bold_mpp'];
elseif any(strcmpi(COHORT,{'Beijing','Cambridge'}))
    Path2ImgDir = [Path2ImgRaw '/rest_mpp'];
end

Path2ImgRaw=[PATH2AUX '/ExampleData/R.mpp'];
Path2ImgDir = ['/Users/sorooshafyouni/Home/GitClone/FILM2/Externals/ROCKLAND/sub-' SubID '/ses-' SesID '/sub-' SubID '_ses-' SesID '_task-rest_acq-645_bold_mpp'];

fwhmlab='';
if lFWHM
    fwhmlab=['_fwhm' num2str(lFWHM)];
end

if ~icaclean
    icalab = 'off';
    Path2Img    = [Path2ImgDir '/prefiltered_func_data_bet' fwhmlab '.nii.gz'];
elseif icaclean==1
    icalab = 'nonaggr';
    Path2Img    = [Path2ImgDir '/ica-aroma' fwhmlab '/denoised_func_data_nonaggr.nii.gz'];
elseif icaclean==2
    icalab = 'aggr';
    Path2Img    = [Path2ImgDir '/ica-aroma' fwhmlab '/denoised_func_data_nonaggr.nii.gz'];
end

Path2MC  = [Path2ImgDir '/prefiltered_func_data_mcf.par'];

disp(['Image: ' Path2Img])
disp(['Motion params: ' Path2MC])

% Directory 2 save the results
Path2ImgResults=[PATH2AUX '/ExampleData/R.mpp/RNullfMRI_' SubID '_' SesID];
if ~exist(Path2ImgResults, 'dir')
	mkdir(Path2ImgResults)
	disp(['The directory: ' Path2ImgResults ' did not exists. I made one. '])
end

disp(['Output stuff: ' Path2ImgResults])

%%% Read The Data %%%%%%%%%%%%%%%%%%%%%%%%
disp('=====LOAD THE IMAGE ===========================')

% ----------------------------------------------
% one day this bit should be moved into the CleanNIFTI_spm.m
% CLK	 = fix(clock);
% tmpdir  = [tempdir 'octspm12/tmp_' num2str(randi(5000)) '_' num2str(CLK(end))]; % make a temp directory 
% mkdir(tmpdir)
% disp(['Unzip into: ' tmpdir ])
% randtempfilename=[tmpdir '/prefilt_tmp_' SubID '_' num2str(randi(50)) num2str(CLK(end)+randi(10)) '.nii'];
% system(['gunzip -c ' Path2Img ' > ' randtempfilename]); %gunzip function in Octave deletes the source file in my version!

[Y,InputImgStat]=CleanNIFTI_spm(Path2Img,'demean');

% disp(['Remove the temp directory: ' tmpdir])
% %rmdir(tmpdir,'s')
% system(['rm -rf ' tmpdir])



%-----------------------------------------------

T     = InputImgStat.CleanedDim(2);
TR    = InputImgStat.voxelsize(4);
Vorig = InputImgStat.CleanedDim(1);
V = Vorig;

if size(Y,1)~=T; Y = Y'; end; %TxV

%%% DETREND %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if DoDetrendingPrior
    pp = 1+fix(TR.*T/150);
    dY = multpolyfit(repmat(1:T,Vorig,1),Y,T,pp);
    dY = dY - mean(dY,2); 
else
    dY = Y; 
end

%%% SIMULATIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Order of AR which will be used to simulated stuff
% ARporder = 20;
% ARParam  = AR_YW(dYorig,ARporder);
% nRlz = 1000; 
% model = arima('Constant',0,'AR',ARParam,'Variance',1);
% dY = simulate(model,T,'NumPaths',nRlz)'; 
% dY = dY - mean(dY,2); 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% DESIGN MATRIX %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('++++++++++++ Construct a design matrix')
%%% Generate a Design Matrix --------------------------------

if strcmpi(EDtype,'boxcar')
    BCl = 20;
    EDX = GenerateED(BCl,T,TR); 
    EDX = EDX - mean(EDX); 
    Xc  = 1; % where is the experimental design?
elseif strcmpi(EDtype,'er')
    BCl = 0;
    path2evs=[PATH2AUX '/mis/EVs/' COHORT '_sub_' SubID '_T' num2str(T) '_TR' num2str(TR*1000) '.txt'];
    EDX = load(path2evs);
end
disp(['The paradigm is: ' EDtype])

X   = EDX;

disp(['design updated, ' num2str(size(X,2))])
% Motion parameters ----------------------------------------
MCp = [];
if MParamNum     == 6
    MCp = load(Path2MC);
elseif MParamNum == 12
    MCp = load(Path2MC);
    MCp = [MCp,MCp.^2]; % 12 parameter motion 
elseif MParamNum == 24
    o6MCp   = load(Path2MC);  % 6 orig param
    so6MCp  = o6MCp.^2;       % 6 square orig
    do6MCp  = diff(o6MCp);    % 6 diff
    do6MCp  = [ do6MCp; zeros(1,size(do6MCp,2)) ];
    sd6MCp  = do6MCp.^2;      % 6 square of diff
    %sd6MCp  = [ sd6MCp; zeros(1,size(sd6MCp,2)) ];
    MCp     = [o6MCp,so6MCp,do6MCp,sd6MCp];
end
disp(['Number of motion parameter: ' num2str(MParamNum)])

X = [X,MCp];
disp(['design updated, ' num2str(size(X,2))])

% Global Signal -----------------------------------------
if gsrflag
    GSRts = mean(Y,2); 
    X = [X,GSRts];
    disp(['global signal regression: ' num2str(size(GSRts,1)) ' x ' num2str(size(GSRts,2))])
    disp(['design updated, ' num2str(size(X,2))]) 
end


% Temporal trends ----------------------------------------
TempTrend = [];
if ~exist('NumTmpTrend','var'); NumTmpTrend=[]; end;
if any(strcmpi(TempTreMethod,{'dct','spline','poly'}))
    [TempTrend,NumTmpTrend]   = GenerateTemporalTrends(T,TR,TempTreMethod,NumTmpTrend); % DC + Poly trends + Spline trends 
    TempTrend   = TempTrend(:,2:end); % we add a column of one later.
elseif strcmpi(TempTreMethod,{'hpf'})
    if isempty(NumTmpTrend) || ~exist('NumTmpTrend','var'); NumTmpTrend=100; end; 
    hp_ff = hp_fsl(T,NumTmpTrend,TR);    
    X     = hp_ff*X;    % high pass filter the design
    dY    = hp_ff*dY;  % high pass filter the data
end
disp(['Detrending: ' TempTreMethod ',param: ' num2str(NumTmpTrend)])
%
X           = [X,TempTrend];
disp(['design updated, ' num2str(size(X,2))])

% Centre the design  ----------------------------------
X           = X - mean(X); % demean everything 

%%% RESIDUALS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('++++++++++++Get the residuals using I-XX+')
pinvX           = pinv(X); 
ResidFormingMat = eye(T)-X*pinvX; % residual forming matrix 
residY          = ResidFormingMat*dY;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% BIAS REDUCTION OF AUTOREGRESSIVE MODELS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

ACFadjflag = 0; WrosleyFlag = 0; ACFflag = 0; ARMAHRflag = 0; ARMA_ReMLflag = 0; MPparamNum = 0; 
if strcmpi(pwdmethod,'AR-W') %Worsely %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    WrosleyFlag = 1;     
    invM_biasred = ACFBiasAdj(ResidFormingMat,T,Mord);    
elseif strcmpi(pwdmethod,'ACFadj') % Yule-Walker %%%%%%%%%%%%%%%%%%%%%%%%%%%
    ACFadjflag          = 1; 
    invM_biasred = ACFBiasAdj(ResidFormingMat,T,Mord); 
elseif strcmpi(pwdmethod,'ACF') % ACF %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    ACFflag         = 1;
elseif strcmpi(pwdmethod,'ARMAHR') % ARMAHR %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    ARMAHRflag      = 1; 
    MPparamNum      = 1;  % the MA order 
    ARParamARMA     = 50; % the higher fit in ARMA HR
elseif strcmpi(pwdmethod,'ARMAReML') % ARMAHR %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    ARMA_ReMLflag   = 1; 
    Mdl          = arima(1,0,1);
    Mdl.Constant = 0;
    Mdl.Variance = 1;    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% FIT A MODEL TO THE ACd DATA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('++++++++++++Fit data to the Naive model.')
X0                                          = [ones(T,1),X];
glmcont                                     = zeros(1,size(X0,2));
glmcont([2,3])                              = [1 -1];
[Bhat_Naive,~,resNaive,Stat_Naive_SE_tmp]   = myOLS(dY,X0,glmcont);
SE_Naive                                    = Stat_Naive_SE_tmp.se;
tVALUE_Naive                                = Stat_Naive_SE_tmp.tval;
[~,CPSstat_Naive,CPZ_Naive]                 = CPSUnivar(resNaive,X0);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% AUTOCORR & AUTOCOV %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% ACFs %%%%%%%%%%%%%%%
disp(['++++++++++++Calculate the autocorrelation coefficients.'])
%residY         = residY-mean(residY); 
residY          = residY-repmat(mean(residY),T,1);
[~,~,dRESacov]  = AC_fft(residY,T); % Autocovariance; VxT

if ACFadjflag || ACFflag
    disp('Will be running SUSAN on the autocovariances.')
    %dRESacov    = ApplyFSLSusan(dRESacov,5,InputImgStat,[Path2ImgDir '/mask.nii.gz']);
    dRESacov    = ApplyFSLSmoothing(dRESacov,5,InputImgStat,[Path2ImgDir '/mask.nii.gz']);
end

dRESacov        = dRESacov'; %TxV
dRESacorr       = dRESacov./dRESacov(1,:);
%dRESacorr       = dRESacov./sum(abs(residY).^2); % Autocorrelation
ACL             = sum(dRESacorr.^2); % Autocorrelation Length

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% PREWHITEN THE RESIDULAS & ESTIMATE BIAS AND CPS %%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% Preallocate memory
Bhat_PW    = zeros(V,1);
SE_PW      = zeros(V,1); 
tVALUE_PW  = zeros(V,1);
CPSstat_PW = zeros(V,1); 
CPZ_PW     = zeros(V,1);
dpwRES     = zeros(T,V); 
nonstationaryvox = [];
disp('++++++++++++Starts the voxel-wise prewhitening')

for vi = 1:V
    spdflag = 0;
    if ACFadjflag % ACF, Tapered, Adjusted %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if ~mod(vi,5000); disp([ pwdmethod ' ::: on voxel ' num2str(vi)]); end; 
        
        [sqrtmVhalf,spdflag] = ACF_ResPWm(dRESacov(:,vi),Mord,invM_biasred,1);
           
    elseif ACFflag % ACF - Tapered, Adjusted %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if ~mod(vi,5000); disp([ pwdmethod ' ::: on voxel ' num2str(vi)]); end; 
        
        [sqrtmVhalf,spdflag] = ACF_ResPWm(dRESacov(:,vi),Mord,[],1);
        
    elseif WrosleyFlag % Worsely %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if ~mod(vi,5000); disp([ pwdmethod ' ::: on voxel ' num2str(vi)]); end; 
        
        [sqrtmVhalf,spdflag] = AR_ResPWm(dRESacov(:,vi),Mord,invM_biasred);
        
    elseif ARMAHRflag % ARMA HR %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if ~mod(vi,5000); disp(['ARMA-HR ::: on voxel ' num2str(vi)]); end; 
  
        %AR_YW -------------------------------------------
        ac_tmp              = dRESacorr(:,vi);    
        R_tmp               = toeplitz(ac_tmp(1:ARParamARMA));
        r_tmp               = ac_tmp(2:ARParamARMA+1);
        %YWARparam_tmp       = pinv(R_tmp)*r_tmp %
        YWARparam_tmp       = R_tmp\r_tmp;
        % ------------------------------------------------
        
        [arParam,maParam]    = ARMA_HR_ACF(residY(:,vi),YWARparam_tmp',T,Mord,MPparamNum);
        ACMat                = ARMACovMat([arParam,maParam],T,Mord,MPparamNum);
        [sqrtmVhalf,spdflag] = CholWhiten(ACMat);
        
        
    elseif ARMA_ReMLflag
        if ~mod(vi,1000); disp(['ARMA-ReML ::: on voxel ' num2str(vi)]); end; 
        a  = estimate(Mdl,residY(:,vi),'Display','off');
        arParam=a.AR{1}; 
        maParam=a.MA{1};
        ACMat                = ARMACovMat([arParam,maParam],T,1,1);
        [sqrtmVhalf,spdflag] = CholWhiten(ACMat);
    end

    if spdflag
        nonstationaryvox = [nonstationaryvox vi];
    end
    % Make the X & Y whitened %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    Ystar_YW = sqrtmVhalf*dY(:,vi);
    Xstar_YW = sqrtmVhalf*X;   
    %YvWY(vi) = corr(Ystar_YW,dY(:,vi)); % idon't know how useful that is.
    % Fit a model to the prewhitened system  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
    Xstar_YW                                      = [ones(T,1), Xstar_YW]; % add intercept
    [Bhat_PW_S_tmp,~,dpwRES_tmp,Stat_PW_SE_T_tmp] = myOLS(Ystar_YW,Xstar_YW,glmcont);
    Bhat_PW(vi)    = Bhat_PW_S_tmp;         
    SE_PW(vi)      = Stat_PW_SE_T_tmp.se;
    tVALUE_PW(vi)  = Stat_PW_SE_T_tmp.tval;

    dpwRES(:,vi)       = dpwRES_tmp;
    Ystar(:,vi)        = Ystar_YW;
    
    [~,CPSstat_PW(vi),CPZ_PW(vi)] = CPSUnivar(dpwRES_tmp,Xstar_YW);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SPECTRUM OF THE RESIDUALS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('++++++++++++Calculate the spectrum of the residuals.')
[dpwRESXp,dpwRESYp] = DrawMeSpectrum(dpwRES,TR,0);
dpwRESYp            = mean(dpwRESYp,2); % average across voxels

%clear dpwRES

[resNaiveSXp,resNaiveYp] = DrawMeSpectrum(resNaive,TR,0);
resNaiveYp               = mean(resNaiveYp,2); % average across voxels

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SAVE THE RESULTS AS AN IMAGE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('++++++++++++Save the results.')

if SaveImagesFlag
    % 3D IMAGES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    VariableList = {'Bhat_Naive','SE_Naive','tVALUE_Naive',...
        'Bhat_PW','SE_PW','tVALUE_PW',...
        'CPSstat_PW','CPZ_PW',...
        'CPZ_Naive','CPSstat_Naive',...
        'ACL'};
    OutputImgStat            = InputImgStat.spmV(1);
    OutputImgStat.Removables = InputImgStat.Removables;

    for vname = VariableList

        tmpvar     = eval(vname{1});
        fname      = [Path2ImgResults '/ED' EDtype '_' num2str(BCl) '_' pwdmethod '_AR' num2str(Mord) '_MA' num2str(MPparamNum) '_FWHM' num2str(lFWHM) '_' TempTreMethod num2str(NumTmpTrend) '_' vname{1} '_ICACLEAN' num2str(icaclean) '_GSR' num2str(gsrflag) '.nii'];

        CleanNIFTI_spm(tmpvar,'ImgInfo',InputImgStat.spmV,'DestDir',fname,'removables',InputImgStat.Removables);
        %system(['gzip ' fname]);
    end
end

% MAT FILES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if SaveMatFileFlag
    GLM.df = Stat_Naive_SE_tmp.df; 
    GLM.X  = X0;
    GLM.C  = glmcont;
    GLM.EDtype = EDtype;
    GLM.EDFreq = BCl; 
    
    SPEC.X_RES   = resNaiveSXp;
    SPEC.Y_RES   = resNaiveYp;
    SPEC.X_pwRES = dpwRESXp;
    SPEC.Y_pwRES = dpwRESYp;
    
    PW.dt     = TempTreMethod;
    PW.dtl    = NumTmpTrend;
    PW.pwmeth = pwdmethod;
    PW.fwhm   = lFWHM;
    PW.MAp    = MPparamNum;
    PW.ARp    = Mord;
    PW.nonSPD = nonstationaryvox;
    
    MatFileName = [Path2ImgResults '/ED' EDtype '_' num2str(BCl) '_' pwdmethod '_AR' num2str(Mord) '_MA' num2str(MPparamNum) '_FWHM' num2str(lFWHM) '_' TempTreMethod num2str(NumTmpTrend) '_ICACLEAN' num2str(icaclean) '_GSR' num2str(gsrflag) '.mat'];
    save(MatFileName,'GLM','SPEC','PW')
end

disp('xxDONExx')
