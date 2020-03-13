
function [CS, JCS] = CS_tibia_Kai2014(Tibia, DistTib, result_plots, debug_plots)

% default behaviour of results/debug plots
if nargin<3;     result_plots = 1;  end
if nargin<4;     debug_plots = 0;  end

% if this is an entire tibia then cut it in two parts
% but keep track of all geometries
if ~exist('DistTib','var') || isempty(DistTib)
    % Only one mesh, this is a long bone that should be cutted in two
    % parts
    V_all = pca(Tibia.Points);
    [ProxTib, DistTib] = cutLongBoneMesh(Tibia);
    [ ~, CenterVol] = TriInertiaPpties( Tibia );
else
    % join two parts in one triangulation
    ProxTib = Tibia;
    Tibia = TriUnite(DistTib, ProxTib);
    [ V_all, CenterVol] = TriInertiaPpties( Tibia );
end

% checks on vertical direction
Z0 = V_all(:,1);
Z0 = sign((mean(ProxTib.Points)-mean(DistTib.Points))*Z0)*Z0;

% Slices 1 mm apart as in Kai et al. 2014
slices_thick = 1;
[~, ~, ~, ~, AltAtMax] = TriSliceObjAlongAxis(Tibia, Z0, slices_thick);

% slice at max area
[ Curves , ~, ~ ] = TriPlanIntersect(Tibia, Z0 , -AltAtMax );

% keep just the largest outline (tibia section)
[maxAreaSection, N_curves] = GIBOK_getLargerPlanarSect(Curves);

% check number of curves
if N_curves>2
    warning(['There are ', num2str(N_curves), ' section areas.']);
    error('This should not be the case (only tibia and possibly fibula should be there).')
end

% Move the outline curve points in the inertial ref system, so the vertical
% component (:,1) is on a plane
PtsCurves = vertcat(maxAreaSection.Pts)*V_all;

% Fit a planar ellipse to the outline of the tibia section
FittedEllipse = fit_ellipse(PtsCurves(:,2), PtsCurves(:,3));

% depending on the largest axes, YElpsMax is assigned.
% vector shapes justified by the rotation matrix used in fit_ellipse
% R       = [ cos_phi sin_phi; 
%             -sin_phi cos_phi ];
if FittedEllipse.a>FittedEllipse.b
    % horizontal ellipse
    YElpsMax = V_all*[ 0; cos(FittedEllipse.phi); -sin(FittedEllipse.phi)];
else
    % vertical ellipse - get
    YElpsMax = V_all*[ 0; sin(FittedEllipse.phi); cos(FittedEllipse.phi)];
end

% check ellipse fitting
if debug_plots == 1
    figure
    ax1 = axes();
    plot(ax1, PtsCurves(:,2), PtsCurves(:,3)); hold on; axis equal
    FittedEllipse = fit_ellipse(PtsCurves(:,2), PtsCurves(:,3), ax1);
    plot([0 50], [0, 0], 'r', 'LineWidth', 4)
    plot([0 0], [0, 50], 'g', 'LineWidth', 4)
    xlabel('X'); ylabel('Y')
end

% centre of ellipse back to medical images reference system
CenterEllipse = transpose(V_all*[mean(PtsCurves(:,1)); % constant anyway
                                 FittedEllipse.X0_in;
                                 FittedEllipse.Y0_in]);

% identify lateral direction
[U_tmp, MostDistalMedialPt, ~] = tibia_identify_lateral_direction(DistTib, Z0);

% making Y0/U_temp normal to Z0 (still points laterally)
Y0_temp = normalizeV(U_tmp' - (U_tmp*Z0)*Z0); 

% here the assumption is that Y0 has correct m-l orientation               
YElpsMax = sign(Y0_temp'*YElpsMax)*YElpsMax;

EllipsePts = transpose(V_all*[ones(length(FittedEllipse.data),1)*PtsCurves(1) FittedEllipse.data']');

% common axes: X is orthog to Y and Z, which are not mutually perpend
Y = normalizeV(Z0);
Z = normalizeV(YElpsMax);
X = cross(Y, Z);

% segment reference system
CS.Origin        = CenterVol;
% CS.ElpsMaxPtVect = YElpsMax;
CS.ElpsPts       = EllipsePts;
CS.X = X;
CS.Y = Y;
CS.Z = Z;
CS.V = [X Y Z];

% define the knee reference system
Ydp_knee  = cross(Z, X);
JCS.knee_r.Origin = CenterEllipse;
JCS.knee_r.V = [X Ydp_knee Z];
JCS.knee_r.child_orientation = computeZXYAngleSeq(JCS.knee_r.V);

% the knee axis is defined by the femoral fitting
% CS.knee_r.child_location = KneeCenter*dim_fact;

% the talocrural joint is also defined by the talus fitting.
% apart from the reference system -> NB: Z axis to switch with talus Z
% CS.ankle_r.parent_orientation = computeZXYAngleSeq(CS.V_knee);

% plot reference systems
if result_plots == 1
    PlotTriangLight(Tibia, CS, 1);
    quickPlotRefSystem(CS);
    quickPlotRefSystem(JCS.knee_r);
    % plot largest section
    plot3(maxAreaSection.Pts(:,1), maxAreaSection.Pts(:,2), maxAreaSection.Pts(:,3),'r-', 'LineWidth',2); hold on
    plotDot(MostDistalMedialPt, 'r', 4);
    title('Tibia - Kai et al. 2014')
end

end
