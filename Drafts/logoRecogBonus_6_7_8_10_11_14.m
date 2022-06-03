tiledlayout("flow");

imgs = getImgs();
imgsGray = getImgsGrayed();
imgsLogosGrayed = getImgsLogosGrayed();
logoNames = getLogoNames();

%meanF = ones(9,9) / 81;

for i = 16 : 16   %length(imgs)
    nexttile;
    imshow(imgsGray{i});
    title("Gray Image");

    imgsMedian{i} = uint8(medfilt2(imgsGray{i}, [15 15]));
    nexttile;
    imshow(imgsMedian{i});
    title("Median Smoothing");
    
    func = @(x) licensePlateColor(x);
    imgsFiltered{i} = imbinarize(nlfilter(imgsMedian{i}, [21 21], func));
    
    nexttile;
    imshow(imgsFiltered{i});
    title("Custom Filtered");
    
    se = strel('disk', 7);
    imgsClosed{i} = imclose(imgsFiltered{i}, se);
    nexttile;
    imshow(imgsClosed{i});
    title("Closing Image");

    imgsFilled{i} = imfill(imgsClosed{i}, "holes");
    nexttile;
    imshow(imgsFilled{i});
    title("Filling Components");

    imgsOpened{i} = imopen(imgsFilled{i}, strel('rectangle', [10 40]));
    nexttile;
    imshow(imgsOpened{i});
    title("Opening To Get Rectangles", "FontSize", 8);

    CC = bwconncomp(imgsClosed{i});
    connPixelsCount = cellfun(@numel, CC.PixelIdxList); %getting num of pixels per component
    [biggestComps, idxs] = maxk(connPixelsCount,length(connPixelsCount)); %getting biggest components' locations (idxs, eg: 1 8 9 10 6 etc)
    for j = 1 : 1 %removing biggest component only
        imgsClosed{i}(CC.PixelIdxList{idxs(j)}) = 0;
    end
    nexttile;
    imshow(imgsClosed{i});
    title("Removing Largest Component", "FontSize", 9);

    

    CC = bwconncomp(imgsOpened{i});
    platePossibleLocs = regionprops(CC, 'Centroid', 'MajorAxisLength', 'Area');
    platePossibleLocs.Area
    [rows, cols] = size(imgsOpened{i});
    imgCenterPoint(1) = round(cols / 2); %assign x-coor (cols)
    imgCenterPoint(2) = round(rows / 2); %assign y-coor (rows)
    %^^ Those two steps are done to be compatible with the
    %platePossibleLocs(j).Centroid's [x y] format in the loop below

    norms = zeros(length(platePossibleLocs),1);
    for j = 1 : length(norms)
        norms(j) = norm(imgCenterPoint - platePossibleLocs(j).Centroid);
        if (platePossibleLocs(j).MajorAxisLength > 200 ...
                || platePossibleLocs(j).Area < 1000)
            norms(j) = 999;
        end
    end
    
    [nearCenterComps, idxs] = mink(norms,length(norms));
    length(idxs)
    CC.PixelIdxList
    for j = 2 : length(idxs) %obtaining component nearest to img center only
        imgsOpened{i}(CC.PixelIdxList{idxs(j)}) = 0;
    end
    nexttile;
    imshow(imgsOpened{i});
    title("After getting most centered");

    radius = min(size(imgsGray{i}, 1), size(imgsGray{i}, 2)) / 11;
    circ = drawcircle('Center', platePossibleLocs(idxs(1)).Centroid, ...
        'Radius', radius, 'Visible', 'off');
    %this line ^ shows the image (equivalent to nexttile; imshow(imgsOpened{i});)
    
    bwMask = createMask(circ);
    nexttile;
    imshow(bwMask);
    title("Circle Mask Based On Image's Size", "FontSize", 7);
    %break;
    figure;
    minDiff = realmax; %realmax --> 1.797693134862316e+308
    logoLoc = -1;
    finalX = 0;
    finalY = 0;
    z = 0;
    for x = 0.0 : 0.3 : 0.6
        for y = -2 : 0.2 : 2
            imgCropped{i} = maskAndCropAndZoom(imgsGray{i}, bwMask, radius*x, radius*y);
            imgCropped{i} = imresize(imgCropped{i}, [64 64]);
            nexttile;
            imshow(imgCropped{i}); % To see the translations for the approximately 3*20 images (for some reason it shows 63 images) 
            [diff, loc] = compareImg(imgCropped{i}, imgsLogosGrayed, 2, 3);
            if diff < minDiff
                minDiff = diff;
                logoLoc = loc;
                finalX = x;
                finalY = y;
            end
        end
    end
    imgLogoSubimage = maskAndCropAndZoom(imgsGray{i}, bwMask, radius*finalX, radius*finalY, imgs{i});
    nexttile;
    imshow(imgLogoSubimage);
    title(logoNames{logoLoc});
    %nexttile;
    %imshow(imgsLogosGrayed{logoLoc});
    %title("Matched With This Logo"); %To show the logo that it matched with in the database

end

%%%%%%%%%%%%%%%%%%%%%% Function to get license plate lines  %%%%%%%%%%%%%%%%%%%%%%
function platePoint = licensePlateColor(imgPlatePart)
    [rows, cols] = size(imgPlatePart);
    grays = 0;
    whites = 0;
    for i = 1 : 4 %floor(rows/3)
        for j = 1 : cols
            if imgPlatePart(i, j) >= 45 && imgPlatePart(i, j) <= 90
                grays = grays + 1;
            end
        end
    end

    for i = 11 : 14
        for j = 1 : cols
            if imgPlatePart(i, j) >= 100 && imgPlatePart(i, j) <= 220
                whites = whites + 1;
            end
        end
    end

    if whites > grays && abs(whites - grays) < 40
        platePoint = 255;
    else
        platePoint = 0;
    end
end

%%%%%%%%%%%%%%%%%%%%%% Function to crop logo area by masking then zoom to center  %%%%%%%%%%%%%%%%%%%%%%
function imgCropped = maskAndCropAndZoom(img, bwMask, transX, transY, imgRgb)
    
    bwMask = imtranslate(bwMask, [transX transY], 'FillValues', 0, 'OutputView', 'same');
    
    bound = regionprops(bwMask, 'BoundingBox');
    coords = bound.BoundingBox;
    
    imgCircled = uint8(bwMask) .* img;
    imgCropped = imcrop(imgCircled, [coords(1), coords(2), coords(3), coords(4)]); %x, y, height and width of bounding box

    [rows, cols] = size(imgCropped);
    coords(1) = coords(1) + cols/7;
    coords(2) = coords(2) + rows/4;
    coords(3) = coords(3) - cols/3;
    coords(4) = coords(4) - rows/2;
    if nargin < 5 % means that argument "imgRgb" was not provided in function's call
        imgCropped = imcrop(imgCircled, [coords(1), coords(2), coords(3), coords(4)]); %x, y, width, height of bounding box
    else
        imgCropped = imcrop(imgRgb, [coords(1), coords(2), coords(3), coords(4)]);
    end
    
end


%%%%%%%%%%%%%%%%%%%%%% Function to get Features of logos (labels)  %%%%%%%%%%%%%%%%%%%%%%
function labelsFeaturesVectorOrElem = getFeatures(singleOrMultiple, imgOrimgsCellArr, numFeatures)
    
    if strcmp(singleOrMultiple, 'single')
        imgEdged = double(imgOrimgsCellArr);
        lf = fft2(double(imgEdged));
        lf = abs(lf(:)); %The "(:)" is to convert a row vector to a col vector
        lf = sort(lf, 'descend');
        lf = lf(1:numFeatures);
        labelsFeaturesVectorOrElem = lf;

    elseif strcmp(singleOrMultiple, 'multiple')
        for i = 1 : length(imgOrimgsCellArr)
            imgEdged = double(imgOrimgsCellArr{i});
            lf = fft2(imgEdged);
            lf = abs(lf(:));
            lf = sort(lf, 'descend');
            lf = lf(1:numFeatures);
            labelsFeaturesVectorOrElem(:, i) = lf; %"(:, i)" is to replace all rows of a column i with the i'th image's features
        end

    end

end

%%%%%%%%%%%%%%%%%%%%%% Function to compare img with logos & return smallest difference and it's corresponding logo index in the logos database  %%%%%%%%%%%%%%%%%%%%%%
function [diff, loc] = compareImg(reqImg, imgsToCompareWith, numFeatures, numNearestLabels)
    
    reqImgFeatures = getFeatures('single', reqImg, numFeatures);
    labelsFeaturesVector = getFeatures('multiple', imgsToCompareWith, numFeatures);
    for i = 1 : size(labelsFeaturesVector, 2) %loop over all label images (car logos)
        sqrdDiff(i) = 0;
        for j = 1 : numFeatures %loop over all features of the i'th label image
            sqrdDiff(i) = sqrdDiff(i) + (reqImgFeatures(j) - labelsFeaturesVector(j, i))^2;
        end
    end
    
    sqrdDiff = sqrt(sqrdDiff);

    [minDiffs, idxs] = mink(sqrdDiff, numNearestLabels);
    %nexttile;
    %imshow(imgsToCompareWith{idxs(1)});
    
    diff = minDiffs(1);
    loc = idxs(1);
end

%%%%%%%%%%%%%%%%%%%%%%  Function to get Logo Names from file names of logo .png files  %%%%%%%%%%%%%%%%%%%%%%
function logoNames = getLogoNames()
    logosNamesCells = dir("logos\");
    logosNamesCells = {logosNamesCells.name};
    for i = 3 : length(logosNamesCells) %to leave out "." and ".."
        matchStr = regexp(logosNamesCells{i}, '\..+\.', 'match');
        if (length(matchStr) > 0) && (length(matchStr{1}) > 3)
            logoNames{i-2} = matchStr{1}(2:length(matchStr{1})-1);
        end
    end
end

function imgs = getImgs()
    imgs{1} = imread("TestCases\Case1\Case1-Front1.bmp");
    imgs{2} = imread("TestCases\Case2\Case2-Front2.jpg");
    imgs{3} = imread("TestCases\Case2\Case2-Rear1.jpg");
    imgs{4} = imread("TestCases\Case2\Case2-Rear2.jpg");
    %bonus cases
    
    imgs{5} = imread("TestCases\Bounses\Case3\Case 3-1.jpg");
    imgs{6} = imread("TestCases\Bounses\Case3\Case 3-2.jpg");
    imgs{7} = imread("TestCases\Bounses\Case3\Case 3-3.jpg");
    imgs{8} = imread("TestCases\Bounses\Case3\Case 3-4.jpg");
    
    imgs{9} = imread("TestCases\Bounses\Case4\Case 4-1.jpg");
    imgs{10} = imread("TestCases\Bounses\Case4\Case 4-2.jpg");
    imgs{11} = imread("TestCases\Bounses\Case4\Case 4-3.jpg");
    
    imgs{12} = imread("TestCases\Bounses\Case5\1.jpg");
    imgs{13} = imread("TestCases\Bounses\Case5\7.jpg");
    imgs{14} = imread("TestCases\Bounses\Case5\8.jpg");
    imgs{15} = imread("TestCases\Bounses\Case5\9.jpg");
    imgs{16} = imread("TestCases\Bounses\Case5\10.jpg");
end

function imgsGrayed = getImgsGrayed()
    imgsGrayed{1} = rgb2gray(imread("TestCases\Case1\Case1-Front1.bmp"));
    imgsGrayed{2} = rgb2gray(imread("TestCases\Case2\Case2-Front2.jpg"));
    imgsGrayed{3} = rgb2gray(imread("TestCases\Case2\Case2-Rear1.jpg"));
    imgsGrayed{4} = rgb2gray(imread("TestCases\Case2\Case2-Rear2.jpg"));
    %bonus cases
    
    imgsGrayed{5} = rgb2gray(imread("TestCases\Bounses\Case3\Case 3-1.jpg"));
    imgsGrayed{6} = rgb2gray(imread("TestCases\Bounses\Case3\Case 3-2.jpg"));
    imgsGrayed{7} = rgb2gray(imread("TestCases\Bounses\Case3\Case 3-3.jpg"));
    imgsGrayed{8} = rgb2gray(imread("TestCases\Bounses\Case3\Case 3-4.jpg"));
    
    imgsGrayed{9}  = rgb2gray(imread("TestCases\Bounses\Case4\Case 4-1.jpg"));
    imgsGrayed{10} = rgb2gray(imread("TestCases\Bounses\Case4\Case 4-2.jpg"));
    imgsGrayed{11} = rgb2gray(imread("TestCases\Bounses\Case4\Case 4-3.jpg"));
    
    imgsGrayed{12} = rgb2gray(imread("TestCases\Bounses\Case5\1.jpg"));
    imgsGrayed{13} = rgb2gray(imread("TestCases\Bounses\Case5\7.jpg"));
    imgsGrayed{14} = rgb2gray(imread("TestCases\Bounses\Case5\8.jpg"));
    imgsGrayed{15} = rgb2gray(imread("TestCases\Bounses\Case5\9.jpg"));
    imgsGrayed{16} = rgb2gray(imread("TestCases\Bounses\Case5\10.jpg"));
end

function imgsLogos = getImgsLogos()
    imgsLogos{1} = imread("logos\01.opel.png");
    imgsLogos{2} = imread("logos\02.kia.png");
    imgsLogos{3} = imread("logos\03.hyundai.png");
    imgsLogos{4} = imread("logos\04.Hyundai.png");
    %bonus cases
    
    imgsLogos{5} = imread("logos\05.bmw.png");
    imgsLogos{6} = imread("logos\06.kia.png");
    imgsLogos{7} = imread("logos\07.chevrolet.png");
    imgsLogos{8} = imread("logos\08.speranza.png");
    
    imgsLogos{9} = imread("logos\09.Hyundai.png");
    imgsLogos{10} = imread("logos\10.Hyundai.png");
    imgsLogos{11} = imread("logos\11.speranza.png");
    
    imgsLogos{12} = imread("logos\12.kia.png");
    imgsLogos{13} = imread("logos\13.toyota.png");
    imgsLogos{14} = imread("logos\14.Hyundai.png");
    imgsLogos{15} = imread("logos\15.toyota.png");
    imgsLogos{16} = imread("logos\16.skoda.png");
end

function imgsLogosGrayed = getImgsLogosGrayed()
    imgsLogosGrayed{1} = rgb2gray(imread("logos\01.opel.png"));
    imgsLogosGrayed{2} = rgb2gray(imread("logos\02.kia.png"));
    imgsLogosGrayed{3} = rgb2gray(imread("logos\03.hyundai.png"));
    imgsLogosGrayed{4} = rgb2gray(imread("logos\04.Hyundai.png"));
    %bonus cases
    
    imgsLogosGrayed{5} = rgb2gray(imread("logos\05.bmw.png"));
    imgsLogosGrayed{6} = rgb2gray(imread("logos\06.kia.png"));
    imgsLogosGrayed{7} = rgb2gray(imread("logos\07.chevrolet.png"));
    imgsLogosGrayed{8} = rgb2gray(imread("logos\08.speranza.png"));
    
    imgsLogosGrayed{9}  = rgb2gray(imread("logos\09.Hyundai.png"));
    imgsLogosGrayed{10} = rgb2gray(imread("logos\10.Hyundai.png"));
    imgsLogosGrayed{11} = rgb2gray(imread("logos\11.speranza.png"));
    
    imgsLogosGrayed{12} = rgb2gray(imread("logos\12.kia.png"));
    imgsLogosGrayed{13} = rgb2gray(imread("logos\13.toyota.png"));
    imgsLogosGrayed{14} = rgb2gray(imread("logos\14.Hyundai.png"));
    imgsLogosGrayed{15} = rgb2gray(imread("logos\15.toyota.png"));
    imgsLogosGrayed{16} = rgb2gray(imread("logos\16.skoda.png"));

    for i = 1 : length(imgsLogosGrayed)
        imgsLogosGrayed{i} = imresize(imgsLogosGrayed{i}, [64 64]);
    end
end

%{
figure;
se = strel('disk', 4);
for i = 1 : length(imgs)
    imgsDilate{i} = imdilate(imgsCanny{i}, se);
    nexttile;
    imshow(imgsDilate{i});
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