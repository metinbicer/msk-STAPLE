function CSs = createFemurCoordMiranda2010(DistFem, CSs)


% TODO: double check against manuscript

%% Compute the femur diaphysis axis
[V_all, Center0] = TriInertiaPpties( DistFem );

%
Z0 = V_all(:,1);
X0 = V_all(:,3);
Y0 = V_all(:,2);
coeff = -1;

% slicing femur along the "long" dimension

% TODO: This should be every mm, not on 200 points
Alt = linspace( min(DistFem.Points*Z0)+0.1 ,max(DistFem.Points*Z0)-0.1, 200);
Area=[];
for d = Alt
    [ Curves , Area(end+1), ~ ] = TriPlanIntersect(DistFem, coeff*Z0 , d );
end

% compare with Fig 3 of Miranda publication.
% bar(Area)

%=======================================
% figure
% trisurf(DistFem.ConnectivityList, DistFem.Points(:,1), DistFem.Points(:,2), DistFem.Points(:,3),'Facecolor','m','Edgecolor','none');
% light; lighting phong; % light
% hold on, axis equal
% curves not usable because not stored
%=======================================

% first location: maximum area
[maxArea,ImaxArea] = max(Area);
Loc1 = Alt(ImaxArea);

% second location: 1/2 maximum area (after the first location)
AreasPastMax=Area(ImaxArea:end);
[~,Id] = min(abs(maxArea/2-AreasPastMax));
% Original code had a bug here -missed -1 - [LM]
Loc2 = Alt(ImaxArea+Id-1);

% idenfication of diaphysis
% TODO: should be Alt(0)
dd = Loc2 - min(Alt);

% ElmtsDia = find(DistFem.incenter*Z0>(dd+1.3*(dd-min(Alt))));
% ElmtsEpi = find(DistFem.incenter*Z0<(dd+1.3*(dd-min(Alt))));

ElmtsDia = find(DistFem.incenter*Z0>(min(Alt) + 1.3*dd));
ElmtsEpi = find(DistFem.incenter*Z0<(min(Alt) + 1.3*dd));

DiaFem = TriReduceMesh( DistFem, ElmtsDia );
DiaFem = TriFillPlanarHoles(DiaFem);
% %=======================================
% figure
% trisurf(DiaFem.ConnectivityList, DiaFem.Points(:,1), DiaFem.Points(:,2), DiaFem.Points(:,3),'Facecolor','m','Edgecolor','none');
% light; lighting phong; % light
% hold on, axis equal
% curves not usable because not stored
%=======================================

%[ DiaFem_InertiaMatrix, DiaFem_Center ] = InertiaProperties( DiaFem.Points, DiaFem.ConnectivityList );

% updated
[V_DiaFem, DiaFem_Center] = TriInertiaPpties( DiaFem );

Zdia = V_DiaFem(:,1);

EpiFem = TriReduceMesh( DistFem, ElmtsEpi );

%=======================================
figure
trisurf(EpiFem.ConnectivityList, EpiFem.Points(:,1), EpiFem.Points(:,2), EpiFem.Points(:,3),'Facecolor','m','Edgecolor','none');
light; lighting phong; % light
hold on, axis equal
% curves not usable because not stored
%=======================================

%% Find Pt1 described in their method

LinePtNodes = bsxfun(@minus, EpiFem.Points, DiaFem_Center');

CP = (cross(repmat(Zdia',length(LinePtNodes),1),LinePtNodes));

Dist = sqrt(sum(CP.^2,2));
[~,IclosestPt] = min(Dist);
Pt1 = EpiFem.Points(IclosestPt,:);

plot3(Pt1(1),Pt1(2),Pt1(3),'o','LineWidth',4)

%% Find Pt2
% Get the curves of the cross section at 
[ Curves , ~, ~ ] = TriPlanIntersect(DistFem, coeff*Z0 , min(Alt) + dd );

for c = 1:length(Curves)
    plot3(Curves(c).Pts(:,1), Curves(c).Pts(:,2), Curves(c).Pts(:,3),'k'); hold on; axis equal
end


% Get the center of the bounding box inertial axis algined
NewPts = V_all'*Curves.Pts'; NewPts = NewPts';
CenterCS_0 = [mean(NewPts(:,1)),0.5*(min(NewPts(:,2))+max(NewPts(:,2))),0.5*(min(NewPts(:,3))+max(NewPts(:,3)))];
CenterCS = V_all*CenterCS_0';

% IDX = knnsearch(Curves.Pts,CenterCS','K',100);
IDX = knnsearch(Curves.Pts,CenterCS');

Uap = Curves.Pts(IDX,:)-CenterCS';
Uap = Uap'/norm(Uap);

PosteriorPts = Curves.Pts(Curves.Pts*Uap>CenterCS'*Uap,:);


% ClosestPts = Curves.Pts(IDX,:);


% The Point P2

LinePtNodes = bsxfun(@minus, PosteriorPts, CenterCS');

CP = (cross(repmat(X0',length(LinePtNodes),1),LinePtNodes));

Dist = sqrt(sum(CP.^2,2));
[~,IclosestPt] = min(Dist);
Pt2 = PosteriorPts(IclosestPt,:);

plot3(Pt2(1),Pt2(2),Pt2(3),'ro','LineWidth',4)

tic
%% Define first plan iteration
npcs = cross( Pt1-Pt2, Y0); npcs = npcs'/norm(npcs);

if (Center0'-Pt1)*npcs > 0
    npcs = -npcs;
end

ElmtsDPCs = find(EpiFem.incenter*npcs > Pt1*npcs);
PCsFem = TriReduceMesh( EpiFem, ElmtsDPCs );

% First Cylinder Fit
Axe0 = Y0';
Radius0 = 0.5*(max(PCsFem.Points*npcs)-min(PCsFem.Points*npcs));

[x0n, an, rn, d] = lscylinder(PCsFem.Points(1:3:end,:), mean(PCsFem.Points)' - 2*npcs, Axe0, Radius0, 0.001, 0.001);

plotCylinder( an, rn, x0n, 15, 1, 'b')

%% Define second plan iteration
npcs = cross( Pt1-Pt2, an); npcs = npcs'/norm(npcs);

if (Center0'-Pt1)*npcs > 0
    npcs = -npcs;
end

ElmtsDPCs = find(EpiFem.incenter*npcs > Pt1*npcs);
PCsFem = TriReduceMesh( EpiFem, ElmtsDPCs );

% Second and last Cylinder Fit
Axe0 = an/norm(an);
Radius0 = rn;

[x0n, an, rn, d] = lscylinder(PCsFem.Points(1:3:end,:), x0n, Axe0, Radius0, 0.001, 0.001);



EpiPtsOcyl_tmp = bsxfun(@minus,PCsFem.Points,x0n');

CylStart = min(EpiPtsOcyl_tmp*an)*an' + x0n';
CylStop = max(EpiPtsOcyl_tmp*an)*an' + x0n';

CylCenter = 1/2*(CylStart + CylStop);

plotCylinder( an, rn, x0n, norm(CylStart - CylStop), 1, 'r')

Results.Yend_Miranda = an;
Results.Xend_Miranda = cross(an,Zdia); 
Results.Xend_Miranda = Results.Xend_Miranda  / norm(Results.Xend_Miranda);
Results.Zend_Miranda = cross(Results.Xend_Miranda,Results.Yend_Miranda);
Results.CenterKnee_Miranda = CylCenter;

end