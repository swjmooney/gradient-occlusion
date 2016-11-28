function MaskContourShader(mask)
    
    % Create shaded ribbon along contours of mask. Mask name should not
    % include "_mask".
    
    if isa(mask,'char')
        mask_name = mask;
        mask = ReadGray(sprintf('images/terrains/masks/%s.tif',mask));
    end
    
    if isa(mask,'uint16')
        mask_alpha = double(mask)/(2^16-1);
    elseif isa(mask,'uint8')
        mask_alpha = double(mask)/(2^8-1);
    end
    
    binary = imbinarize(mask);
    edges = edge(binary);
    try
        load(sprintf('images/terrains/masks/vectors/%s.mat',mask_name));
    catch
        disp('Could not load vectors. Creating and saving...');
        [~,vectors] = AnalyseMaskEdges(binary);
        save(sprintf('images/terrains/masks/vectors/%s.mat',mask_name),'vectors');
    end
    dists = bwdist(edges);
    
    %% PARAMETERS
    
    % Ribbon parameters
    
    width = 2;
    ribbon_pixels = (dists<=width) .* ~binary .* ~edges;
    %ribbon_alpha = (1-dists/width).^1.5 .* ribbon_pixels;
    
    % Shading parameters
    
    intensity = 1;
    offset = 0.5;
    amplitude = 0.5;
    azimuth = pi/2;
    background = .5;
    falloff = 1;
    
    % IDW parameters
    
    IDWweight = -1;
    IDWradius = 3*width;
    
    %% Shade contour using linear falloff
    
    ang_dst = abs(vectors - pi + azimuth);                                  % Distance from azimuth
    ang_dst(ang_dst>pi) = 2*pi - ang_dst(ang_dst>pi);                       % Distance in [0 pi]
    lum = intensity * max(0, ...
        lerp(offset+amplitude,offset-amplitude,ang_dst/(falloff*pi)));      % Interpolate between O+A and O-A from [0 pi].
    
    %% Create IDW
    
    IDWimage = CreateIDW(ribbon_pixels,edges,IDWweight,IDWradius);
    imwrite(IDWimage,sprintf('images/%s_width%d_weight%d_narrow.tif',mask_name,width,IDWweight),'tif');
    save(sprintf('images/%s_width%d_weight%d_narrow_pixels.mat',mask_name,width,IDWweight),'ribbon_pixels');
    figure(1); clf;
    imshow(IDWimage);
    
    function IDWimage = CreateIDW(IDWpixels,IDWstations,weight,r)
        
        [iRows,iCols] = find( IDWpixels );
        [eRows,eCols] = find( IDWstations );
        
        lumInd = sub2ind(size(mask),eRows,eCols);
        lumVec = lum(lumInd);

        IDWimage = IDW(eCols,eRows,lumVec,iCols,iRows,...                   % Shade IDW
            weight,'fr',r,size(mask,1),1);
        
        IDWimage = IDWimage.*ribbon_pixels + 0.5*~ribbon_pixels;
        %IDWimage = IDWimage.*(ribbon_alpha) + 0.5*(1-ribbon_alpha);
        %IDWimage = IDWimage.*(1-mask_alpha) + 0.5*(mask_alpha);
        
        IDWimage = (IDWimage-min(IDWimage(:))) / (max(IDWimage(:))-min(IDWimage(:)));
        
        if isa(mask,'uint16')
            IDWimage = uint16(IDWimage * (2^16-1));
        elseif isa(mask,'uint8')
            IDWimage = uint8(IDWimage * (2^8-1));
        end
    end
    
end

function [mask_edges,mask_vectors] = AnalyseMaskEdges(mask_binary,mask_vectors)
   
    if (nargin<2 || isempty(mask_vectors))
        
        mask_edges = edge(mask_binary);
        mask180 = skeletonOrientation(mask_edges,[9 9]);
        mask_vectors = deg2rad(GetMaskOrientations(mask_binary,mask180));
        
    end
    
    % Put maskVectors inside [-pi pi]
    mask_vectors(mask_vectors>pi) = mask_vectors(mask_vectors>pi) - 2*pi;
    
end

function point = lerp(a,b,p)
    
    % Interpolate point p in [0 1] between a and b.
    
    point = a + (b-a) * p;
    
end