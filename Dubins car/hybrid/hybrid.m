function [ fx, y ] = hybrid(  )

close all;
addpath('..\..\lib');

% parameters
v = 1;
u = [0,2,-2];
sigma = 0.2;
xo1 = [0,-1.5,1.5];
xo2 = [0.5,1,1];
No = length(xo1);
d = 0.5;
epsilon = 1e6;

% grid
N1 = 100; N2 = 100;
L1 = 6; L2 = 6;
x1 = linspace(-L1/2,L1/2-L1/N1,N1);
x2 = linspace(-L2/2,L2/2-L2/N2,N2);
N3 = 50;
x3 = linspace(-pi,pi-2*pi/N3,N3);
Nt = 161;
Lt = 4;
t = linspace(0,Lt,Nt);

% initial conditions
x1_0 = 0; x2_0 = -2;
sigma1_0 = 0.2; sigma2_0 = 0.2;
x3_0 = pi/2;
k_0 = 20;
s_0 = 1;

% initial distribution
fx = zeros(N1,N2,N3,3,Nt);
fx(:,:,:,s_0,1) = 1/(sqrt(2*pi)*sigma1_0)*exp(-0.5*(reshape(x1,[],1,1)-x1_0).^2/sigma1_0^2) .* ...
    (1/(sqrt(2*pi)*sigma2_0)*exp(-0.5*(reshape(x2,1,[],1)-x2_0).^2/sigma2_0^2)) .* ...
    (1/(2*pi*besseli(0,k_0))*exp(k_0*cos(reshape(x3,1,1,[])-x3_0)));

% Fourier transform of initial distribution
y = zeros(N1,N2,N3,3,Nt);
shift1 = reshape((-1).^((0:N1-1)-N1/2),[],1,1);
shift2 = reshape((-1).^((0:N2-1)-N2/2),1,[],1);
shift3 = reshape((-1).^((0:N3-1)-N3/2),1,1,[]);
for s = 1:3
    y(:,:,:,s,1) = fftshift(fftn(fx(:,:,:,s,1)))/N1/N2/N3;
    y(:,:,:,s,1) = y(:,:,:,s,1).*shift1.*shift2.*shift3;
end

% Fourier transfor for sin(theta) and cos(theta)
ysin = fftshift(fft(sin(x3)))/N3;
ysin = ysin.*reshape(shift3,1,[]);
ycos = fftshift(fft(cos(x3)))/N3;
ycos = ycos.*reshape(shift3,1,[]);

% coefficients continuous propagation
ACont = zeros(N3,N3,N1,N2,3);
c1 = [0,ones(1,N1-1)];
c2 = [0,ones(1,N2-1)];
c3 = [0,ones(1,N3-1)];
for s = 1:3
    for n1 = 1:N1
        for n2 = 1:N2
            for n3 = 1:N3
                for j3 = 1:N3
                    n3minusj3 = wrapDFT(n3-j3,N3)+1+N3/2;
                    part1 = -2*pi*1i*(n1-1-N1/2)*c1(n1)*v/L1*ycos(n3minusj3);
                    part2 = -2*pi*1i*(n2-1-N2/2)*c2(n2)*v/L2*ysin(n3minusj3);
                    ACont(n3,j3,n1,n2,s) = part1+part2;
                end

                part3 = -1i*(n3-1-N3/2)*c3(n3)*u(s);
                part4 = -0.5*sigma^2*(n3-1-N3/2)^2;
                ACont(n3,n3,n1,n2,s) = ACont(n3,n3,n1,n2,s)+part3+part4;
            end
        end
    end
end

expACont = zeros(N3,N3,N1,N2,3);
for s = 1:3
    for n1 = 1:N1
        for n2 = 1:N2
            expACont(:,:,n1,n2,s) = expm(ACont(:,:,n1,n2,s)*Lt/(Nt-1));
        end
    end
end
clear ACont;

% coefficients discrete propagation
G1_1 = cell(No,1); G1_2 = cell(No,1); G1_3 = cell(No,1);
G2_1 = cell(No,1); G2_2 = cell(No,1); G2_3 = cell(No,1);
for no = 1:No
    thetao = atan2(xo2(no)-x2,xo1(no)-x1');
    [G1_1{no},G1_2{no},G1_3{no}] = ind2sub([N1,N2,N3],find(sqrt((x1'-xo1(no)).^2+(x2-xo2(no)).^2)<d &...
        wrapToPi(thetao-reshape(x3,1,1,[]))>=0 &...
        wrapToPi(thetao-reshape(x3,1,1,[]))<pi));
    [G2_1{no},G2_2{no},G2_3{no}] = ind2sub([N1,N2,N3],find(sqrt((x1'-xo1(no)).^2+(x2-xo2(no)).^2)<d &...
        wrapToPi(thetao-reshape(x3,1,1,[]))>=-pi &...
        wrapToPi(thetao-reshape(x3,1,1,[]))<0));
end
G1_1 = cat(1,G1_1{:}); G1_2 = cat(1,G1_2{:}); G1_3 = cat(1,G1_3{:});
G2_1 = cat(1,G2_1{:}); G2_2 = cat(1,G2_2{:}); G2_3 = cat(1,G2_3{:});
[G3_1,G3_2] = find(sqrt((x1'-xo1(1)).^2+(x2-xo2(1)).^2)>=d &...
    sqrt((x1'-xo1(2)).^2+(x2-xo2(2)).^2)>=d &...
    sqrt((x1'-xo1(3)).^2+(x2-xo2(3)).^2)>=d);

ADisc = cell(3,1);
ADisc{1} = [-epsilon,0,0;0,0,0;epsilon,0,0];
ADisc{2} = [-epsilon,0,0;epsilon,0,0;0,0,0];
ADisc{3} = [0,epsilon,epsilon;0,-epsilon,0;0,0,-epsilon];
expADisc = cellfun(@(x)expm(x*Lt/(Nt-1)),ADisc,'UniformOutput',false);

% propagation
for nt = 2:Nt
    % continuous
    for n1 = 1:N1
        for n2 = 1:N2
            for s = 1:3
                y(n1,n2,:,s,nt) = reshape(expACont(:,:,n1,n2,s)*reshape(y(n1,n2,:,s,nt-1),[],1),1,1,[]);
            end
        end
    end
    
    % reconstruct density
    for s = 1:3
        fx(:,:,:,s,nt) = ifftn(ifftshift(y(:,:,:,s,nt)./shift1./shift2./shift3*n1*n2*n3),'symmetric');
    end
    
    % renormalize
    fx(:,:,:,:,nt) = fx(:,:,:,:,nt)/(sum(sum(sum(sum(fx(:,:,:,:,nt)))))*L1/N1*L2/N2*(2*pi)/N3);
    
    % discrete
    for s = 1:length(G1_1)
        fx(G1_1(s),G1_2(s),G1_3(s),:,nt) = ...
            reshape(expADisc{1}*reshape(fx(G1_1(s),G1_2(s),G1_3(s),:,nt),[],1),1,1,1,[]);
    end

    for s = 1:length(G2_1)
        fx(G2_1(s),G2_2(s),G2_3(s),:,nt) = ...
            reshape(expADisc{2}*reshape(fx(G2_1(s),G2_2(s),G2_3(s),:,nt),[],1),1,1,1,[]);
    end

    for s = 1:length(G3_1)
        for n3 = 1:N3
            fx(G3_1(s),G3_2(s),n3,:,nt) = ...
                reshape(expADisc{3}*reshape(fx(G3_1(s),G3_2(s),n3,:,nt),[],1),1,1,1,[]);
        end
    end
    
    % Fourier transform
    for s = 1:3
        y(:,:,:,s,nt) = fftshift(fftn(fx(:,:,:,s,nt)))/N1/N2/N3;
        y(:,:,:,s,nt) = y(:,:,:,s,nt).*shift1.*shift2.*shift3;
    end
end

% plot
for nt = 1:4:Nt
    figure;
    plot(x3,reshape(sum(sum(sum(fx(:,:,:,:,nt)*L1/N1*L2/N2,1),2),4),[],1,1));
end

for nt = 1:4:Nt
    figure; hold on;
    for no = 1:No
        scatter3(xo1(no),xo2(no),1,'Marker','o','SizeData',20,'MarkerFaceColor','k','MarkerEdgeColor','k');
        plot3(xo1(no)+d*cos(0:0.01:2*pi),xo2(no)+d*sin(0:0.01:2*pi),ones(1,length(0:0.01:2*pi)),'Color','k','LineWidth',3);
    end
    surf(x1,x2,sum(sum(fx(:,:,:,:,nt)*2*pi/N3,3),4)');
    view([0,0,1]);
end

% save data
parameter.x1 = x1;
parameter.x2 = x2;
parameter.x3 = x3;
parameter.t = t;
parameter.xo1 = xo1;
parameter.xo2 = xo2;
parameter.d = d;
save(strcat('D:\result-dubins car\',sprintf('%i-%i-%i-%i-%i-%i',round(clock)),'-splitting','.mat'),'parameter','fx');

rmpath('..\..\lib');

end

