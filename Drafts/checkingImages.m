tiledlayout("flow");

imgs{1} = imread("TestCases\Case1\Case1-Front1.bmp");
imgs{2} = imread("TestCases\Case2\Case2-Front2.jpg");
imgs{3} = imread("TestCases\Case2\Case2-Rear1.jpg");
imgs{4} = imread("TestCases\Case2\Case2-Rear2.jpg");

%meanF = ones(9,9) / 81;

for i = 1 : length(imgs)
    imgs{i} = rgb2gray(imgs{i});
    imgs{i} = uint8(medfilt2(imgs{i}, [21 21]));
    nexttile;
    imshow(imgs{i});
    
    imgsCanny{i} = edge(imgs{i}, "canny");
    nexttile;
    imshow(imgsCanny{i});
end

figure;
se = strel('disk', 4);
for i = 1 : length(imgs)
    imgsDilate{i} = imdilate(imgsCanny{i}, se);
    nexttile;
    imshow(imgsDilate{i});
end

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