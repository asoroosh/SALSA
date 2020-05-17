% ts_fname='/Users/sorooshafyouni/Home/GitClone/FILM2/NullRealfMRI/FeatTest/sub-A00008326++++.feat/filtered_func_data.nii.gz';
% tcon_fname='/Users/sorooshafyouni/Home/GitClone/FILM2/NullRealfMRI/FeatTest/sub-A00008326++++.feat/design.con';
% dmat_fname='/Users/sorooshafyouni/Home/GitClone/FILM2/NullRealfMRI/FeatTest/sub-A00008326++++.feat/design_mat.txt';
% path2mask='/Users/sorooshafyouni/Home/GitClone/FILM2/NullRealfMRI/FeatTest/sub-A00008326++++.feat/mask.nii.gz';
% parmat='/Users/sorooshafyouni/Home/GitClone/FILM2/NullRealfMRI/FeatTest/sub-A00008326++++.feat/mc/prefiltered_func_data_mcf.par';
% %feat5/featlib.cc 
% 
% [Y,ImgStat] = CleanNIFTI_spm(ts_fname,'demean');
% Y = Y';
% Y = Y - mean(Y);
% 
% disp('MC params.')
% MCp      = load(parmat); 
% MCp      = GenMotionParam(MCp,24); 
% X        = [ones(T,1) load(dmat_fname) MCp];
% 
% addpath('/Users/sorooshafyouni/Home/GitClone/FILM2/mis')
% 
% % disp('hpf')
% TR  = 0.645;
% ntp = size(Y,1);
% [TempTrend,NumTmpTrend]   = GenerateTemporalTrends(T,TR,'spline',3); % DC + Poly trends + Spline trends 
% X       = [X TempTrend(:,2:end)];
% 
% 
% 
% tcon     = zeros(1,size(X,2));
% tcon(2)  = 1;
% 
% 
% [cbhat,RES,stat,se,tv,zv,Wcbhat,WYhat,WRES,wse,wtv,wzv] = arw5(Y,X,tcon,10,ImgStat,path2mask);
% 
% [PSDx,PSDy]   = DrawMeSpectrum(RES,1);
% [WPSDx,WPSDy] = DrawMeSpectrum(WRES,1);
% 
% figure; hold on; grid on; 
% plot(PSDx,mean(PSDy,2))
% plot(WPSDx,mean(WPSDy,2))


function [cbhat,RES,stat,se,tv,zv,Wcbhat,WYhat,WRES,wse,wtv,wzv] = arw(Y,X,tcon,ARO,ImgStat,path2mask)
% Y    : TxV
% X    : TxEV. X should have the detreding basis + motion parameters
% tcon : 1xEV
%
%
% SA, Ox, 2020

    ntp                   = size(Y,1); 
    nvox                  = size(Y,2); 
    [cbhat,~,~,stat] = myOLS(Y,X,tcon); % if cbhat is not needed; R=I-(XX+); RES=RY

    se                   = stat.se;
    tv                   = stat.tval;
    zv                   = stat.zval;
    
    pinvX               = pinv(X); 
    ResidFormingMat     = eye(ntp)-X*pinvX; % residual forming matrix 
    RES                 = ResidFormingMat*Y;

    % find the acf of the residuals
    [~,~,dRESacov]      = AC_fft(RES,ntp); % Autocovariance; VxT
    dRESacov            = dRESacov';
    dRESacov            = dRESacov(1:ARO+1,:); %cut-off here so smoothing gets much faster
    
    % smooth ACF
    FWHMl               = 5; 
    dRESacov            = ApplyFSLSmoothing(dRESacov',FWHMl,ImgStat,path2mask)';
    % bias adjusting matrix 
    BiasAdj             = ACFBiasAdjMat(ResidFormingMat,ntp,ARO); 

    % refit the model to pre-whitened data
    Wcbhat  = zeros(1,nvox);
    WYhat   = zeros(ntp,nvox); 
    WRES    = zeros(ntp,nvox);
    wse     = zeros(nvox,1); 
    wtv     = zeros(nvox,1);
    wzv     = zeros(nvox,1);
    for iv = 1:nvox
        if ~mod(iv,5000); disp(['on voxel: ' num2str(iv)]); end; 
        sqrtmVhalf = establish_prewhiten_matrix(dRESacov(:,iv),ntp,BiasAdj);
        WYv        = sqrtmVhalf*Y(:,iv);
        WX         = sqrtmVhalf*X;   
        [Wcbhat(iv),WYhat(:,iv),WRES(:,iv),wstat] = myOLS(WYv,WX,tcon);
        
        wse(iv)  = wstat.se;
        wtv(iv)  = wstat.tval;
        wzv(iv)  = wstat.zval;
        %WY(:,iv)   = WYv;
    end

end

function [sqrtmVhalf,posdef] = establish_prewhiten_matrix(autocov,ntp,BiasAdj)
% dRESacov : autocovariance 
% Mord : Order required 
% BiasAdj: bias adjustment matrix 
%
% SA, Ox, 2020
%
     
    %dRESac_adj              = (BiasAdj*autocov(1:AROrd+1));
    dRESac_adj              = BiasAdj*autocov;
    dRESac_adj              = dRESac_adj./dRESac_adj(1); % make a auto*correlation*
    
    [Ainvt,posdef]          = chol(toeplitz(dRESac_adj)); 
    p1                      = size(Ainvt,1); % this is basically posdef - 1, but we'll keep it as Keith Worsely's code. 
    A                       = inv(Ainvt'); 
    
    sqrtmVhalf              = toeplitz([A(p1,p1:-1:1) zeros(1,ntp-p1)],zeros(1,ntp)); 
    sqrtmVhalf(1:p1,1:p1)   = A;
    
end

function invM_biasred = ACFBiasAdjMat(ResidFormingMat,ntp,ARO)
% Bias adjustment for ACF of residuals. 

    M_biasred   = zeros(ARO+1);
    for i=1:(ARO+1)
        Di                  = (diag(ones(1,ntp-i+1),i-1)+diag(ones(1,ntp-i+1),-i+1))/(1+(i==1));
        for j=1:(ARO+1)
           Dj               = (diag(ones(1,ntp-j+1),j-1)+diag(ones(1,ntp-j+1),-j+1))/(1+(j==1));
           M_biasred(i,j)   = trace(ResidFormingMat*Di*ResidFormingMat*Dj)/(1+(i>1));
        end
    end
    invM_biasred = inv(M_biasred);
    
end