% ts_fname='/Users/sorooshafyouni/Home/GitClone/FILM2/NullRealfMRI/FeatTest/sub-A00008326++++.feat/filtered_func_data.nii.gz';
% tcon_fname='/Users/sorooshafyouni/Home/GitClone/FILM2/NullRealfMRI/FeatTest/sub-A00008326++++.feat/design.con';
% dmat_fname='/Users/sorooshafyouni/Home/GitClone/FILM2/NullRealfMRI/FeatTest/sub-A00008326++++.feat/design_mat.txt';
% path2mask='/Users/sorooshafyouni/Home/GitClone/FILM2/NullRealfMRI/FeatTest/sub-A00008326++++.feat/mask.nii.gz';
% parmat='/Users/sorooshafyouni/Home/GitClone/FILM2/NullRealfMRI/FeatTest/sub-A00008326++++.feat/mc/prefiltered_func_data_mcf.par';
% WMSeg='/Users/sorooshafyouni/Home/GitClone/FILM2/NullRealfMRI/FeatTest/sub-A00008326++++.feat/reg/func_wmseg.nii.gz';
% 
% %feat5/featlib.cc 
% 
% addpath('/Users/sorooshafyouni/Home/GitClone/FILM2/mis')
% addpath('/Users/sorooshafyouni/Home/matlab/spm12')
% 
% [Y,ImgStat] = CleanNIFTI_spm(ts_fname,'demean');
% Y  = Y';
% Y  = Y - mean(Y);
% T  = 900;
% TR = 0.645;
% 
% disp('MC params.')
% MCp      = load(parmat); 
% MCp      = GenMotionParam(MCp,24); 
% X        = [load(dmat_fname) MCp];
% 
% disp('hpf')
% K     = hp_fsl(size(Y,1),100,0.645);    
% X     = K*X;    % high pass filter the design
% Y     = K*Y;  % high pass filter the data
% 
% X = [ones(T,1) X];
% tcon     = zeros(1,size(X,2));
% tcon(2)  = 1;
% 
% tukey_m   = -2; 
% tukey_f   = 1; 
% path2mask = []; 
% 
% [cbhat,RES,stat,se,tv,zv,Wcbhat,WYhat,WRES,wse,wtv,wzv] = gfeatxfeat5(Y,X,TR,tcon,tukey_m,tukey_f,ImgStat,path2mask,1,K,WMSeg);
% 
% [PSDx,PSDy]   = DrawMeSpectrum(RES,1);
% [WPSDx,WPSDy] = DrawMeSpectrum(WRES,1);
% 
% %figure; 
% hold on; grid on; 
% plot(PSDx,mean(PSDy,2))
% plot(WPSDx,mean(WPSDy,2))


function [cbhat,RES,stat,se,tv,zv,Wcbhat,WYhat,WRES,wse,wtv,wzv] = gfeatxfeat(Y,X,TR,tcon,tukey_m,tukey_f,ImgStat,path2mask,badjflag,K,WMSeg)
% Performs two stage prewhitening: 1) FAST 2) ACFadj
% 
% tcon should already have the intercept
% badjflag [boolean]
% K is the filter
% 

    WYhat = []; % this is not very useful and takes ALOT of memory 
    
    disp(['gfeatxfeat:: fit the intial naive model.'])
    % This bit naturally comes out of the gReML. But keep it here for now. 
    [cbhat,~,RES,stat] = myOLS(Y,X,tcon);
    se                 = stat.se;
    tv                 = stat.tval;
    zv                 = stat.zval;

    if ~exist('WMSeg','var') || isempty(WMSeg)
        disp(['gfeatxfeat:: fit gloabl FAST.-------------------------------'])
        gtukey_m   = -2; % choose optimally  
        gtukey_f   = 1;  % use Tukey
        gaclageval = 0;  % Don't use AR basis
        gbadjflag  = 1;  % Do the bias adjustment
        [WY,WX]                                 = gfeat(Y,X,TR,tcon,gtukey_m,gtukey_f,gaclageval,gbadjflag,K); 
        clear X Y
        disp(['gfeatxfeat:: fit voxel-wise prewhitening. ------------------'])
        [~,~,~,~,~,~,Wcbhat,~,WRES,wse,wtv,wzv] = feat5(WY,WX,tcon,tukey_m,tukey_f,ImgStat,path2mask,badjflag,K);
    else exist('WMSeg','var')
        disp('gfeatxfeat:: prewhitening is being done on segemnts differently.')
        disp('gfeatxfeat:: No ACF smoothing will be done.')
        
        [ntp,nvox]       = size(Y);
        [~,Idx_wm]       = MaskImg(Y',WMSeg,ImgStat); % Time series in WM 
        Idx_wm           = Idx_wm{1};
        
        Ywm              = Y(:,Idx_wm); 
        Idx_gm           = ~Idx_wm;
        Ygm              = Y(:,Idx_gm); % time series in GM & CSF
        
        disp(['gfeatxfeat:: total # of voxels: ' num2str(nvox)])
        disp(['gfeatxfeat:: # of GM voxels: ' num2str(sum(Idx_gm)) ', # of WM voxels: ' num2str(sum(Idx_wm))])
        
        disp('gfeatxfeat:: apply gFAST on grey matter ---------------------')
        gtukey_m   = -2; % choose optimally  
        gtukey_f   = 1;  % use Tukey
        gaclageval = 0;  % Don't use AR basis    
        gbadjflag  = 1;  % Do the bias adjustment
        [WYgm,WXgm]                                            = gfeat(Ygm,X,TR,tcon,gtukey_m,gtukey_f,gaclageval,gbadjflag,K); 
        
        disp('gfeatxfeat:: apply feat5 on the grey matter & CSF -----------')
        [~,~,~,~,~,~,Wcbhat_gm,~,WRES_gm,wse_gm,wtv_gm,wzv_gm] = feat5(WYgm,WXgm,tcon,tukey_m,tukey_f,[],[],badjflag,K);
        
        disp('gfeatxfeat:: apply feat5 on the white matter  ---------------')
        [~,~,~,~,~,~,Wcbhat_wm,~,WRES_wm,wse_wm,wtv_wm,wzv_wm] = feat5(Ywm,X,tcon,tukey_m,tukey_f,[],[],badjflag,K);
        
        % put back the results together.
        Wcbhat = zeros(nvox,1);
        %WYhat  = zeros(ntp,nvox);
        WRES   = zeros(ntp,nvox);
        wse    = zeros(nvox,1);
        wtv    = zeros(nvox,1);
        wzv    = zeros(nvox,1);
        
        % put them back together
        wse(Idx_wm)    = wse_wm ;    wse(Idx_gm)     = wse_gm;
        wtv(Idx_wm)    = wtv_wm ;    wtv(Idx_gm)     = wtv_gm; 
        wzv(Idx_wm)    = wzv_wm ;    wzv(Idx_gm)     = wzv_gm;
        Wcbhat(Idx_wm) = Wcbhat_wm ; Wcbhat(Idx_gm)  = Wcbhat_gm;
        
        %WYhat(:,Idx_wm) = WYhat_wm ; WYhat(:,Idx_gm) = WYhat_gm ;
        WRES(:,Idx_wm)  = WRES_wm  ; WRES(:,Idx_gm)  = WRES_gm ;
        
    end
      
end
