%ASK DR about needing to output logo name or only subimage: both + subimage from
%logos folder can work or not?: YES + grayscale output can work or not?: YES +
%fourier not getting output correctly (e.g img 2): get edges or circularity + when to translate
%upwards to match logo?: if there are lines in car + able to use computerVision toolbox to match or
%no?: YES
tiledlayout("flow");

imgs = getImgs();
imgsLogosGrayed = getImgsLogosGrayed();

%meanF = ones(9,9) / 81;

for i = 2 : 2 %length(imgs)
    imgs{i} = rgb2gray(imgs{i});
    imgsMedian{i} = uint8(medfilt2(imgs{i}, [21 21]));
    nexttile;
    imshow(imgs{i});
    
    imgsBwCanny{i} = edge(imgsMedian{i}, "canny");
    nexttile;
    imshow(imgsBwCanny{i});
    
    se = strel('disk', 4);
    imgsClosed{i} = imclose(imgsBwCanny{i}, se);
    nexttile;
    imshow(imgsClosed{i});


    CC = bwconncomp(imgsClosed{i});
    connPixelsCount = cellfun(@numel, CC.PixelIdxList); %getting num of pixels per component
    [biggestComps, idxs] = maxk(connPixelsCount,length(connPixelsCount)); %getting biggest components' locations (idxs, eg: 1 8 9 10 6 etc)
    for j = 1 : 1 %removing biggest component only
        imgsClosed{i}(CC.PixelIdxList{idxs(j)}) = 0;
    end
    nexttile;
    imshow(imgsClosed{i});

    imgsFilled{i} = imfill(imgsClosed{i}, "holes");
    nexttile;
    imshow(imgsFilled{i});

    imgsOpened{i} = imopen(imgsFilled{i}, strel('rectangle', [10 70]));
    nexttile;
    imshow(imgsOpened{i});
    
    CC = bwconncomp(imgsOpened{i});
    connPixelsCount = cellfun(@numel, CC.PixelIdxList);
    [biggestComps, idxs] = maxk(connPixelsCount,length(connPixelsCount));
    for j = 2 : length(idxs) %obtaining biggest component only
        imgsOpened{i}(CC.PixelIdxList{idxs(j)}) = 0;
    end

    CC = bwconncomp(imgsOpened{i});
    plateLoc = regionprops(CC, 'Centroid');

    radius = min(size(imgs{i}, 1), size(imgs{i}, 2)) / 11;
    circ = drawcircle('Center', plateLoc.Centroid, 'Radius', radius, 'Visible', 'off');
    %this line ^ shows the image (equivalent to nexttile; imshow(imgsOpened{i});)
    
    bwMask = createMask(circ);
    nexttile;
    imshow(bwMask);
    figure;
    minDiff = realmax; %realmax --> 1.797693134862316e+308
    logoLoc = -1;
    for x = 0 : 1 : 0
        for y = -2 : 0.2 : 2
            imgCropped{i} = maskAndCropAndZoom(imgs{i}, bwMask, radius*x, radius*y);
            imgCropped{i} = imresize(imgCropped{i}, [64 64]);
            nexttile;
            imshow(imgCropped{i});
            [diff, loc] = compareImg(imgCropped{i}, imgsLogosGrayed, 2, 3);
            if diff < minDiff
                minDiff = diff;
                logoLoc = loc;
            end
        end
    end
    nexttile;
    imshow(imgsLogosGrayed{logoLoc});

end

%%%%%%%%%%%%%%%%%%%%%% Function to crop logo area by masking then zoom to center  %%%%%%%%%%%%%%%%%%%%%%
function imgCropped = maskAndCropAndZoom(imgGray, bwMask, transX, transY)
    
    bwMask = imtranslate(bwMask, [transX transY], 'FillValues', 0, 'OutputView', 'same');
    %nexttile;
    %imshow(bwMask);
    
    bound = regionprops(bwMask, 'BoundingBox');
    coords = bound.BoundingBox;

    imgCircled = uint8(bwMask) .* imgGray;
    imgCropped = imcrop(imgCircled, [coords(1), coords(2), coords(3), coords(4)]); %x, y, height and width of bounding box
    %nexttile;
    %imshow(imgCropped);

    [rows, cols] = size(imgCropped);
    coords(1) = coords(1) + cols/7;
    coords(2) = coords(2) + rows/4;
    coords(3) = coords(3) - cols/3;
    coords(4) = coords(4) - rows/2;
    imgCropped = imcrop(imgCircled, [coords(1), coords(2), coords(3), coords(4)]); %x, y, width, height of bounding box
    %nexttile;
    %imshow(imgCropped);

end


%%%%%%%%%%%%%%%%%%%%%% Function to get Features of logos (labels)  %%%%%%%%%%%%%%%%%%%%%%
function labelsFeaturesVectorOrElem = getFeatures(singleOrMultiple, imgOrimgsCellArr, numFeatures)
    
    if strcmp(singleOrMultiple, 'single')
        imgEdged = double(edge(imgOrimgsCellArr, 'canny'));
        lf = fft2(double(imgEdged));
        lf = abs(lf(:)); %The "(:)" is to convert a row vector to a col vector
        lf = sort(lf, 'descend');
        lf = lf(1:numFeatures);
        labelsFeaturesVectorOrElem = lf;

    elseif strcmp(singleOrMultiple, 'multiple')
        for i = 1 : length(imgOrimgsCellArr)
            imgEdged = double(edge(medfilt2(imgOrimgsCellArr{i}, [5 5]), 'canny'));
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
    imgsLogos{1} = imread("logos\1.opel1.png");
    imgsLogos{2} = imread("logos\2.kia1.png");
    imgsLogos{3} = imread("logos\3.hyundai1.png");
    imgsLogos{4} = imread("logos\4.Hyundai2.png");
    %bonus cases
    
    imgsLogos{5} = imread("logos\5.bmw1.png");
    imgsLogos{6} = imread("logos\6.kia2.png");
    imgsLogos{7} = imread("logos\7.chevrolet1.png");
    imgsLogos{8} = imread("logos\8.speranza1.png");
    
    imgsLogos{9} = imread("logos\9.Hyundai3.png");
    imgsLogos{10} = imread("logos\10.Hyundai4.png");
    imgsLogos{11} = imread("logos\11.Hyundai5.png");
    
    imgsLogos{12} = imread("logos\12.kia3.png");
    imgsLogos{13} = imread("logos\13.toyota1.png");
    imgsLogos{14} = imread("logos\14.Hyundai6.png");
    imgsLogos{15} = imread("logos\15.toyota2.png");
    imgsLogos{16} = imread("logos\16.skoda1.png");
end

function imgsLogosGrayed = getImgsLogosGrayed()
    imgsLogosGrayed{1} = rgb2gray(imread("logos\1.opel1.png"));
    imgsLogosGrayed{2} = rgb2gray(imread("logos\2.kia1.png"));
    imgsLogosGrayed{3} = rgb2gray(imread("logos\3.hyundai1.png"));
    imgsLogosGrayed{4} = rgb2gray(imread("logos\4.Hyundai2.png"));
    %bonus cases
    
    imgsLogosGrayed{5} = rgb2gray(imread("logos\5.bmw1.png"));
    imgsLogosGrayed{6} = rgb2gray(imread("logos\6.kia2.png"));
    imgsLogosGrayed{7} = rgb2gray(imread("logos\7.chevrolet1.png"));
    imgsLogosGrayed{8} = rgb2gray(imread("logos\8.speranza1.png"));
    
    imgsLogosGrayed{9}  = rgb2gray(imread("logos\9.Hyundai3.png"));
    imgsLogosGrayed{10} = rgb2gray(imread("logos\10.Hyundai4.png"));
    imgsLogosGrayed{11} = rgb2gray(imread("logos\11.Hyundai5.png"));
    
    imgsLogosGrayed{12} = rgb2gray(imread("logos\12.kia3.png"));
    imgsLogosGrayed{13} = rgb2gray(imread("logos\13.toyota1.png"));
    imgsLogosGrayed{14} = rgb2gray(imread("logos\14.Hyundai6.png"));
    imgsLogosGrayed{15} = rgb2gray(imread("logos\15.toyota2.png"));
    imgsLogosGrayed{16} = rgb2gray(imread("logos\16.skoda1.png"));

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