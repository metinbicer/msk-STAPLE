function [CSs, FemHead] = findFemoralHead(ProxFem, CSs)
    
% from CSs structures we need:
% - CSs.CenterVol
% - CSs.Z0

% populates
% CSs.Y0
% CSs.CenterFH0
% CSs.CenterFH
% CSs.RadiusFH

% PARAMETER TO EXPOSE
% FemHead_dil_coeff = 1.5;
%norm_thres

% Find the most proximal on femur top head
[~ , I_Top_FH] = max( ProxFem.incenter*CSs.Z0 ); 
% most prox point
I_Top_FH = [I_Top_FH ProxFem.neighbors(I_Top_FH)]; 
% triang around it
Face_Top_FH = TriReduceMesh(ProxFem,I_Top_FH);
% create a triang with them
[ Patch_Top_FH ] = TriDilateMesh( ProxFem ,Face_Top_FH , 40 );

% Get an initial ML Axis Y0 (pointing medio-laterally)
% NB: from centerVol, OT points upwards to ~HJC, that is more medial than
% Z0, hence cross(CSs.Z0,OT) points anteriorly and Y0 medially
OT = mean(Patch_Top_FH.Points)' - CSs.CenterVol;
CSs.Y0 = normalizeV(  cross(cross(CSs.Z0,OT),CSs.Z0)  );

% Find a the most medial (MM) point on the femoral head (FH)
[~ , I_MM_FH] = max( ProxFem.incenter*CSs.Y0 );
I_MM_FH = [I_MM_FH ProxFem.neighbors(I_MM_FH)];
Face_MM_FH = TriReduceMesh(ProxFem,I_MM_FH);
[ Patch_MM_FH ] = TriDilateMesh( ProxFem ,Face_MM_FH , 40 );

% STEP1: first sphere fit
FemHead0 = TriUnite(Patch_MM_FH,Patch_Top_FH);
% Initial sphere fit
[~, Radius, ErrorDist] = sphereFit(FemHead0.Points);
% RMSE = sqrt(mean(ErrorDist.^2.0));

% TODO:  check the errors at various STEPS to evaluate if fitting is
% improving or not!
% 
% plot3(FemHead0.Points(:,1), FemHead0.Points(:,2), FemHead0.Points(:,3),'.g'); hold on
% title('First fit')


% STEP2: dilate femoral head mesh and sphere fit again
% IMPORTANT: TriDilateMesh "grows" the original mesh, does not create a
% larger one!
FemHead_dil_coeff = 1.5;
[ DilateFemHeadTri] = TriDilateMesh( ProxFem ,FemHead0 , round(FemHead_dil_coeff*Radius) );
[CenterFH,RadiusDil] = sphereFit(DilateFemHeadTri.Points);
CenterFH0 = CenterFH;

% check
if ~RadiusDil>Radius
    warning('Dilated femoral head smaller than original mesh. Please check.')
end

% Theorical Normal of the face (from real fem centre to dilate one)
CPts_PF_2D  = bsxfun(@minus, DilateFemHeadTri.incenter, CenterFH);
normal_CPts_PF_2D = CPts_PF_2D./repmat(sqrt(sum(CPts_PF_2D.^2,2)),1,3);
% % check normals visually
% P=FemHead1.incenter;
% quiver3(P(:,1), P(:,2),P(:,3),...
%     normal_CPts_PF_2D(:,1), normal_CPts_PF_2D(:,2), normal_CPts_PF_2D(:,3)); axis equal

% COND1: Keep points that display a less than 10� difference between the actual
% normals and the sphere simulated normals
FemHead_normals_thresh = 0.975; % acosd(0.975) = 12.87;% deg
Cond1 = sum((normal_CPts_PF_2D.*DilateFemHeadTri.faceNormal),2)>FemHead_normals_thresh;

% COND2: Delete points far from sphere surface outside [90%*Radius 110%*Radius]
Cond2 = abs(sqrt(sum(bsxfun(@minus,DilateFemHeadTri.incenter,CenterFH).^2,2))...
    -1*Radius)<0.1*Radius ;

% [LM] I have found both conditions do not work always, when combined
% check if using both conditions produces results
if sum(Cond1 & Cond2)> 1
    combined_Cond = Cond1 & Cond2;
else

% TODO: find out how to deal with combined conditions not working

    % apply cond 1
    cond1_count = sum(Cond1);
    Face_ID_PF_2D_onSphere = find(Cond1);
    % get the mesh and points on the femoral head
    FemHead1 = TriReduceMesh(DilateFemHeadTri,Face_ID_PF_2D_onSphere);
    FemHead1 = TriOpenMesh(ProxFem ,FemHead1,3);
    plot3(FemHead1.Points(:,1), FemHead1.Points(:,2), FemHead1.Points(:,3),'.b');
    hold on, axis equal
    
    % apply condition 2
    cond2_count = sum(Cond2);
    Face_ID_PF_2D_onSphere = find(Cond2);
    
    % get the mesh and points on the femoral head
    FemHead2 = TriReduceMesh(DilateFemHeadTri,Face_ID_PF_2D_onSphere);
    FemHead2 = TriOpenMesh(ProxFem ,FemHead2,3);
    plot3(FemHead2.Points(:,1), FemHead2.Points(:,2), FemHead2.Points(:,3),'.r');
    
    % export just one cond
    combined_Cond = Cond1;
end
    
combined_cond_count = sum(combined_Cond);

% search within conditions Cond1 and Cond2
Face_ID_PF_2D_onSphere = find(combined_Cond);

% get the mesh and points on the femoral head
FemHead = TriReduceMesh(DilateFemHeadTri,Face_ID_PF_2D_onSphere);
FemHead = TriOpenMesh(ProxFem ,FemHead,3);

% final fem head
plot3(FemHead2.Points(:,1), FemHead2.Points(:,2), FemHead2.Points(:,3),'.r');

% Fit the last Sphere
[CenterFH,Radius, ErrorDistFinal] = sphereFit(FemHead.Points);

%RMSE_final = sqrt(mean(ErrorDistFinal.^2.0));

% Write to the results struct
CSs.CenterFH0 = CenterFH0;
CSs.CenterFH  = CenterFH;
CSs.RadiusFH  =  Radius;

end