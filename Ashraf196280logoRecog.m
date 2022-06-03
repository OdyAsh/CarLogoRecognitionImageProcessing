tiledlayout("flow");

imgs = getImgs();
logosDBGray = getImgsLogosGrayed(); %The logos database
logoNames = getLogoNames(); %The labels (names) of logos database


for i = 1 : length(imgs)
    nexttile;
    imshow(imgs{i});
    title(sprintf("Image %d", i));
    [logo, label] = imgToLogo(imgs{i}, logosDBGray, logoNames, 'noSteps');
end
%change to "i = 1 : 1" and "withSteps" to display detailed steps of first image

%%%%%%%%%%%%%%%%%%%%%% 
% Function to get subimage of a car's logo and its name (label) 
%%%%%%%%%%%%%%%%%%%%%%
function [logo, label] = imgToLogo(imgOrig, logosDBGray, logoNames, withSteps)

    % Step 1:
    % grayscale the image then median filter it

    imgGray = rgb2gray(imgOrig);
    imgMedian = uint8(medfilt2(imgGray, [21 21]));
    displayStep(imgMedian, "Median Smoothing", 11, withSteps);

    % Step 2:
    % use canny edge detection.

    imgBwCanny = edge(imgMedian, "canny");
    displayStep(imgBwCanny, "Canny Edge Detection", 11, withSteps);

    % Step 3:
    % close image to connect edges

    se = strel('disk', 4);
    imgClosed = imclose(imgBwCanny, se);
    displayStep(imgClosed, "Closing Image", 11, withSteps);
    
    % Step 4:
    % get the size (pixel count) of each component in the image
    % to remove the component with the largest size,
    % as it's probably the car's exterior and noise around it

    CC = bwconncomp(imgClosed);
    connPixelsCount = cellfun(@numel, CC.PixelIdxList);
    %^^ getting num of pixels per component
    [~, idxs] = maxk(connPixelsCount,length(connPixelsCount)); 
    %^^ getting biggest components' locations (idxs, eg: 1 8 9 10 6 etc)
    for j = 1 : 1 %removing biggest component only
        imgClosed(CC.PixelIdxList{idxs(j)}) = 0;
    end
    displayStep(imgClosed, "Removing Largest Component", 9, withSteps);
    
    % Step 5:
    % getting circle and/or rectangle filled components

    imgFilled = imfill(imgClosed, "holes");
    displayStep(imgFilled, "Filling Components", 11, withSteps);

    % Step 6:
    % opening image to get rectangles (and possibly small circles)

    imgOpened = imopen(imgFilled, strel('rectangle', [10 40]));
    displayStep(imgOpened, "Opening To Get Rectangles", 8, withSteps);

    % Step 7:
    % getting various properties of the components,
    % then finding the best component that resembles a license plate by
    % passing into a function the image of the components 
    % and its center
    % Example: 1280x720 will be 640x360 
    % so imgCenterPoint will be [360 640]
    % this is to represent it as (x, y) pairs to subtract it from 
    % the component's centroid in bestPlateCandidates()

    CC = bwconncomp(imgOpened);
    platePossibleLocs = regionprops(CC, 'Centroid', 'MajorAxisLength', ...
        'Area', 'Circularity', 'Orientation');
    [imgRows, imgCols] = size(imgOpened);
    imgCenterPoint(1) = round(imgCols / 2); %assign x-coor (cols)
    imgCenterPoint(2) = round(imgRows / 2); %assign y-coor (rows)
    [~, idxs] = bestPlateCandidates(platePossibleLocs, imgCenterPoint);
    for j = 2 : length(idxs) %obtaining component nearest to img center only
        imgOpened(CC.PixelIdxList{idxs(j)}) = 0;
    end
    displayStep(imgOpened, "Best plate candidate", 8, withSteps);

    % Step 8:
    % getting a circle based on dividing the minimum of the image's
    % dimensions over a constant number 
    % (after trial and error, 11 is the best number)
    % Then, create a binary image from the ROI (circle) obtained
    % this binary image will be used in step 9 to mask a subimage 
    % of the original image

    radius = min(imgRows, imgCols) / 11;
    circ = drawcircle('Center', platePossibleLocs(idxs(1)).Centroid, ...
        'Radius', radius, 'Visible', 'off');
    bwMask = createMask(circ);
    displayStep(bwMask, "Circle Mask Based On Image's Size", 7, withSteps);

    % Step 9:
    % using bestSubImage() to translate the binary mask (from step 8)
    % around the component that resembles a license plate (from step 7)
    % At each translation, a subimage is compared with the logos "database"
    % and the most similar image to a logo is retrieved along with its
    % label

    [logo, label] = bestSubImage(imgGray, imgOrig, bwMask, ...
    radius, logosDBGray, logoNames, withSteps);
    nexttile;
    imshow(logo);
    title(label, "FontWeight", "bold", "Color", 'r');
end

%%%%%%%%%%%%%%%%%%%%%% 
% Function to see if a step will be displayed or not
%%%%%%%%%%%%%%%%%%%%%%
function displayStep(imgStep, label, fontSize, str)
    if (strcmp(str, "withSteps"))
        nexttile;
        imshow(imgStep);
        title(label, "FontSize", fontSize);
    end
end

%%%%%%%%%%%%%%%%%%%%%% 
% Function to get best candidates of license plate based on the following:
% 1. Distance from center of image
% 2. ROI not too wide or less than average area of all ROIs
% and either:
% 3. ROI is very circular and has small area
% or:
% 4. ROI is a horizontal rectangle and not near image's borders
%%%%%%%%%%%%%%%%%%%%%%
function [values, idxs] = bestPlateCandidates(plates, imgCenter)
    imgRows = imgCenter(2) * 2;
    imgCols = imgCenter(1) * 2;
    meanOfAreas = mean([plates.Area]);
    norms = zeros(length(plates),1);
    for j = 1 : length(norms)
        p = plates(j);
        norms(j) = norm(imgCenter - p.Centroid); % (1)
        if (p.MajorAxisLength > 1000 ... % (2)
                || p.Area <= meanOfAreas - 1000)
            norms(j) = 2000000;
        end
        if (p.Circularity > 0.85 ... % (3)
                && p.Area <= meanOfAreas - 500)
            norms(j) = norms(j) / 2000;
        elseif (p.Orientation >= -10 && p.Orientation <= 10 ... % (4)
                && p.Centroid(2) > 100 && p.Centroid(2) < imgRows-100 ...
                && p.Centroid(1) > 100 && p.Centroid(1) < imgCols-100)
            norms(j) = norms(j) / 2000;
        else
            norms(j) = norms(j) * 2000;
        end
    end
    [values, idxs] = mink(norms,length(norms));
end

%%%%%%%%%%%%%%%%%%%%%% 
% Function to check subimages around plate region and retrieve the 
% subimage (with label) most similar to the logos in the "database"
% maskAndCropAndZoom() --> gets the subimages
% which are changed to size [64 64] to match images in logos "database"
% compareImg() --> gets the similarity score between a subimage and
% images in the logos "database"
%%%%%%%%%%%%%%%%%%%%%%
function [finalSubImage, label] = bestSubImage(imgGray, origImg, bwMask, ...
    radius, logosDB, logoNames, withSteps)
    if (strcmp(withSteps, "withSteps"))
        figure;
    end
    %^^ this and the imshow() below is to see the translations 
    %for the approximately 60 images (for some reason it shows 63 images) 
    minDiff = realmax; %realmax --> 1.797693134862316e+308
    logoLoc = -1;
    finalX = 0;
    finalY = 0;
    for x = -0.2 : 0.2 : 0.4 %4
        for y = -2 : 0.2 : 1 %15 = 4 * 15 ~= 60 small images
            subImage = maskAndCropAndZoom(imgGray, bwMask, radius*x, radius*y);
            subImage = imresize(subImage, [64 64]);
            displayStep(subImage, "", 11, withSteps);
            [diff, loc] = compareImg(subImage, logosDB, 2, 3);
            if diff < minDiff
                minDiff = diff;
                logoLoc = loc;
                finalX = x;
                finalY = y;
            end
        end
    end

    finalSubImage = maskAndCropAndZoom(imgGray, bwMask, ...
        radius*finalX, radius*finalY, origImg);
    label = logoNames{logoLoc};
end

%%%%%%%%%%%%%%%%%%%%%% 
% Function to crop logo area by masking then zoom to center  
%%%%%%%%%%%%%%%%%%%%%%
function imgCropped = maskAndCropAndZoom(img, bwMask, ...
    transX, transY, imgRgb)
    
    bwMask = imtranslate(bwMask, [transX transY], ...
        'FillValues', 0, 'OutputView', 'same');
    
    bound = regionprops(bwMask, 'BoundingBox');
    coords = bound.BoundingBox;
    
    imgCircled = uint8(bwMask) .* img;
    %nexttile;
    %imshow(imgCircled);

    imgCropped = imcrop(imgCircled, ...
        [coords(1), coords(2), coords(3), coords(4)]); 
    %   x, y, height and width of bounding box 
    %nexttile;
    %imshow(imgCropped);

    [rows, cols] = size(imgCropped);
    coords(1) = coords(1) + cols/7;
    coords(2) = coords(2) + rows/4;
    coords(3) = coords(3) - cols/3;
    coords(4) = coords(4) - rows/2;
    if nargin < 5
        imgCropped = imcrop(imgCircled, ...
            [coords(1), coords(2), coords(3), coords(4)]);
    else
        imgCropped = imcrop(imgRgb, ...
            [coords(1), coords(2), coords(3), coords(4)]);
    end
    % "nargin < 5" means that argument "imgRgb" 
    % was not provided in function's call
    %nexttile;
    %imshow(imgCropped);
end

%%%%%%%%%%%%%%%%%%%%%% 
% Function to compare img with logos 
% & return smallest difference and it's corresponding logo index 
% in the logos "database"  
%%%%%%%%%%%%%%%%%%%%%%
function [diff, loc] = compareImg(reqImg, imgsToCompareWith, ...
    numFeatures, numNearestLabels)

    reqImgFeatures = getFeatures('single', reqImg, numFeatures);
    logosFeatures = getFeatures('multiple', imgsToCompareWith, numFeatures);
    
    for i = 1 : size(logosFeatures, 2) %loop over all label images (car logos)
        sqrdDiff(i) = 0;
        for j = 1 : numFeatures %loop over all features of the i'th label image
            sqrdDiff(i) = sqrdDiff(i) + (reqImgFeatures(j) - logosFeatures(j, i))^2;
        end
    end
    sqrdDiff = sqrt(sqrdDiff);

    [minDiffs, idxs] = mink(sqrdDiff, numNearestLabels);
    %figure
    %nexttile;
    %imshow(imgsToCompareWith{idxs(1)});
    diff = minDiffs(1);
    loc = idxs(1);

end


%%%%%%%%%%%%%%%%%%%%%% 
% Function to get Features of logos (labels)  
%%%%%%%%%%%%%%%%%%%%%%
function logosFeaturesVectorOrMatrix = getFeatures(singleOrMultiple, ...
    imgOrimgsCellArr, numFeatures)
    
    if strcmp(singleOrMultiple, 'single')
        oneImg = double(imgOrimgsCellArr);
        fourier = fft2(oneImg);
        fourier = abs(fourier(:)); %"(:)" is to convert a row vector to a col vector
        fourier = sort(fourier, 'descend');
        fourier = fourier(1:numFeatures);
        logosFeaturesVectorOrMatrix = fourier;

    elseif strcmp(singleOrMultiple, 'multiple')
        for i = 1 : length(imgOrimgsCellArr)
            currImg = double(imgOrimgsCellArr{i});
            fourier = fft2(currImg);
            fourier = abs(fourier(:));
            fourier = sort(fourier, 'descend');
            fourier = fourier(1:numFeatures);
            logosFeaturesVectorOrMatrix(:, i) = fourier; 
            %"(:, i)" is to replace all rows of a column i with the 
            % i'th image's features
        end

    end

end


%%%%%%%%%%%%%%%%%%%%%%  
% Function to get Logo Names from file names 
% of logo .png files  
%%%%%%%%%%%%%%%%%%%%%%
function logoNames = getLogoNames()
    logosNamesCells = dir("logos\");
    logosNamesCells = {logosNamesCells.name};
    for i = 3 : length(logosNamesCells) %to leave out "." and ".."
        matchStr = regexp(logosNamesCells{i}, '\..+\.', 'match');
        if (~isempty(matchStr))
            logoNames{i-2} = matchStr{1}(2:length(matchStr{1})-1);
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%  
% Function to get test cases 
%%%%%%%%%%%%%%%%%%%%%%
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

%%%%%%%%%%%%%%%%%%%%%%  
% Function to get test cases as grayscale
% Not used, but left here just in case
%%%%%%%%%%%%%%%%%%%%%%
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

%%%%%%%%%%%%%%%%%%%%%%  
% Function to get logos (labels)
% Not used, but left here just in case
%%%%%%%%%%%%%%%%%%%%%%
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

%%%%%%%%%%%%%%%%%%%%%%  
% Function to get logos (labels) as grayscale
%%%%%%%%%%%%%%%%%%%%%%
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