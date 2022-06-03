%% FAILED ATTEMPTS
% Most of them were inside the large loop in the
% "logoRecogMainCodeWithNoFunctions.m" file
%{
    %Getting largest component only
    %Didn't work because sometimes largest one is noise (not license plate)
    CC = bwconncomp(imgsOpened{i});
    connPixelsCount = cellfun(@numel, CC.PixelIdxList);
    [biggestComps, idxs] = maxk(connPixelsCount,length(connPixelsCount));
    for j = 2 : length(idxs) %obtaining biggest component only
        imgsOpened{i}(CC.PixelIdxList{idxs(j)}) = 0;
    end
%}

%{
    [centers, radii] = imfindcircles(imadjust(imgs{i}), [20 50], ...
        'ObjectPolarity', 'dark', 'Sensitivity', 0.94);
    h = viscircles(centers, radii);
%}

%{
    %getting rectangle and subtracting from mode
    %h = drawrectangle('Position',[500,500,1000,1000],'StripeColor','r');
    radius = min(size(imgs{i}, 1), size(imgs{i}, 2)) / 5;
    circ = drawcircle('Center', plateLoc.Centroid, 'Radius', radius, 'Visible', 'off');
    %this line ^ shows the image (equivalent to nexttile; imshow(imgsOpened{i});)
    bwMask = createMask(circ);
    imgs{i} = uint8(bwMask) .* imgs{i};

    imgsMode{i} = uint8(modefilt(imgs{i}, [19 19]));
    nexttile;
    imshow(imgsMode{i});

    imgsWithoutBG{i} = imgs{i} - imgsMode{i};
    nexttile;
    imshow(imgsWithoutBG{i});

    bwThresh{i} = imbinarize(imgsWithoutBG{i}, graythresh(imgsWithoutBG{i}));
    nexttile;
    imshow(bwThresh{i});
%}

%{
img1 = rgb2gray(img1);
%nexttile;
%imshow(img1);

img1Canny = edge(img1, "canny");
%nexttile;
%imshow(img1Canny);

img2 = imread("TestCases\Case2\Case2-Front2.jpg");
img2 = rgb2gray(img2);
%nexttile;
%imshow(img2);

meanF = ones(25,25) / 625;
img2 = filter2(meanF, img2);

img2Canny = edge(img2, "canny");
%nexttile;
%imshow(img2Canny);
%}


% Testing boundingBox
%{
for i = 1 : 1 %length(imgs)
    imgs{i} = rgb2gray(imgs{i});
    imgs{i} = uint8(medfilt2(imgs{i}, [21 21]));
    nexttile;
    imshow(imgs{i});
    
    imgsCanny{i} = edge(imgs{i}, "canny");
    nexttile;
    imshow(imgsCanny{i});

    [L, N] = bwlabel(imgsCanny{i}, 8);
    % measure perimeter and bounding box for each blob
    stats = regionprops(imgsCanny{i},{'BoundingBox','perimeter'});
    stats = struct2table(stats);
    % extract the blob whose perimeter is close to round length of its bounding box
    stats.Ratio = 2*sum(stats.BoundingBox(:,3:4),2)./stats.Perimeter;
    idx = abs(1 - stats.Ratio) < 0.1;
    stats(~idx,:) = [];
    for kk = 1:3
      rectangle('Position', stats.BoundingBox(kk,:),...
          'LineWidth',    3,...
          'EdgeColor',    'g',...
          'LineStyle',    ':');
    end
    
end
%}

%{
    %getting edge then filling circle, turns out its same as createMask()
    imgCircled{i} = uint8(bwMask) .* imgs{i};

    imgsBwCanny{i} = edge(imgCircled{i}, "canny");
    nexttile;
    imshow(imgsBwCanny{i});

    %VV this part is to make sure bounding box currectly surrounds the ROI
    imgsClosedThenFilled{i} = imfill(imclose(imgsBwCanny{i}, strel('disk', 5)), 'holes');
    nexttile; 
    imshow(imgsClosedThenFilled{i});

    bound = regionprops(bwMask, 'BoundingBox');
    coords = bound.BoundingBox;
    hold on
    rectangle('Position', [coords(1), coords(2), coords(3), coords(4)],...
        'EdgeColor','r', 'LineWidth', 3)
    imgCropped{i} = imcrop(imgCircled{i}, [coords(1), coords(2), coords(3), coords(4)]); %x, y, height and width of bounding box
    nexttile;
    imshow(imgCropped{i});
%}