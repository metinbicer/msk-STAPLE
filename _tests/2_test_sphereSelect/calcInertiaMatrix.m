function InertiaInfo  = calcInertiaMatrix(aPointCloud)

% COM
COM = mean(aPointCloud);

% move reference frame to COM (still aligned as global ref frame)
x = aPointCloud(:,1)-COM(1);
y = aPointCloud(:,2)-COM(2);
z = aPointCloud(:,3)-COM(3);
% x = aPointCloud(:,1);
% y = aPointCloud(:,2);
% z = aPointCloud(:,3);
% ====== calculating inertia tensor as point cloud =======
Ixx = sum(y.^2.0+z.^2.0);
Iyy = sum(x.^2.0+z.^2.0);
Izz = sum(x.^2.0+y.^2.0);
Ixy = sum(-x.*y);
Ixz = sum(-x.*z);
Iyz = sum(-y.*z);

% inertial tensor
I = [Ixx     Ixy     Ixz;
    Ixy     Iyy     Iyz;
    Ixz     Iyz     Izz];

%======= principal axis of inertia ========
% V: eigenvectors
% D: eigenvalues
% Matlab help:  [V,D] = eig(A,B) with A*V = V*D
% in my case:
% [V,D] = eig(I); 
% which means: I*V = V*D, i.e. I = V*D*V'
%=======================================================================
% IN CONCLUSION: V' is the transformation matrix from the current to the
% inertial reference system
%========================================================================
[V,D] = eig(I);

% ====== collecting all info
InertiaInfo.Mat         = I;
InertiaInfo.COM         = COM;
% Matrix V' allows transformation from current to inertial reference system
% Matrix V contains as colum the vector/ the axes of the inertial reference
% system in the current system -> useful for plotting!
InertiaInfo.PrincAxes   = V';
InertiaInfo.PrincMom    = D;

end