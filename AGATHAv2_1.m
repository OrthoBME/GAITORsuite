function [DATA] = AGATHAv2_1(Input,TopRatFilter,BottomRatFilter,PawFilter,BGCase,Editor)

%% AGATHA Re-write - November 5, 2016 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Kyle D. Allen, Emily H. Lakes, & Brittany Y. Jacobs
%
% Last Updated: August 22, 2017
%   AUG-22-2107: EHL added a case for ConcatenateVideos in the "File Read-
%   in Section".  This consisted of adding 2 "if" statements with a strcmp to
%   see if ConcatenateVideos = 'Y', if so, follow the video concatenation
%   loop.  Else, just name the single video. 
%
% Function Inputs
%   *Input: The name of the Input structure with the naming convention
%       'Input_batch', as designated in Input_Setup.m. 
%       Example: 'Input_Default.mat'
%   *TopRatFilter: The name of the rat filter function created by exporting
%       thresholds from colorThresholder.
%       Example: 'MyExperiment_TopRatFilter.m'
%   *BottomRatFilter: The name of the rat filter function created by exporting
%       thresholds from colorThresholder. If not needed - set to same value as TopRatFilter.
%       Example: 'MyExperiment_BottomRatFilter.m'
%   *PawFilter: The name of the paw filter function created by exporting
%       thresholds from colorThresholder. 
%       Example: 'MyExperiment_PawFilter.m'
%   *BGCase: Background Case dictates which images were used to create the
%       best filters in RatFilter and PawFilter.  
%       Options are:
%       'Rat' means the best filters were made using the rat image with no
%           background, and the paw image with the background.
%       'Paw' means the best filteres were made using the rat image with a
%           background, and the paw image without the background. 
%       'Both' means the best filters were created with the rat and paw
%           images both without the background. 
%       'None' means the best filters were created with the rat and paw
%           images both having the background. 
%   *Editor: Initially, Editor always needs to be set to 'Run'.  However,
%       if the FSTO image needs manually edited, then set to 'Edit' to load 
%       the video and call FSTOEditor. This will skip the frame by frame 
%       FSTO calculation, and simply pull up the previously ran FSTOStruct. 
%
% Function Outputs
%   * AGATHA_Data: A .mat file with these Columns: (assuming no EDGAR)
%       Object #, Fore=1/Hind=0, X-Position at Foot Strike, Frame at Foot
%       Strike, X-Position at Toe Off, Frame at Toe Off, 
%   * Velocity_Data: A .mat file contating x,y data for the bottom view rat
%       centroid and the bottom view nose position for every frame. These
%       will be used in the calculator code to obtain an accurate velocity.
%       

%% Running AGATHA as a Script %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% To troubleshoot AGATHA, please set up AGATHA to run as a script; this
% enables you to utilize the "preloaded video" option as well as preserve
% variables internal to the function for debugging.
% If you want to run this file as a script - change the line below to match
% your Input .mat file name - for example load('Input_Day1.mat'). 
% Also, comment the first "function" line.
load(Input); 

% Also, uncomment the following lines if running as a script and insert 
% your function names and cases.
% TopRatFilter = 'EXratfilter12_bg';
% BottomRatFilter = 'EXratfilter12_bg';
% PawFilter = 'EXpawfilter12_bg';
% BGCase = 'none';
% Editor = 'Run';

% NOTE: You can only use the video preloaded option successfully if you
% run AGATHA as a script for troubleshooting mode. (Make necessary changes
% to top and bottom lines for script functionality.
PreloadedVideo = Input.VideoPreload;

%% Select Videos & Import/Initialize Variables %%%%%%%%%%%%%%%%%%%%%%%%%%%%
switch PreloadedVideo
    case 'Y'
        File = VideoName;
    otherwise
        Directory = uigetdir;
        File = uipickfiles('FilterSpec',Directory,'Type',{'*.avi' '.avi'});
end

% Select the videos you want to run.
% Sets up counters for error and file tracker for batch.
ErrorCount = 1;
FileCount = 1;
Finish = length(File);
ErrVids = [];
TrialIDName = [];

% Convert filters
TopRatFilter = str2func(TopRatFilter);
if strcmp(BottomRatFilter,'No') == 0 || strcmp(BottomRatFilter,'no') == 0
    BottomRatFilter = str2func(BottomRatFilter);
else
    BottomRatFilter = TopRatFiler;
end
PawFilter = str2func(PawFilter);

while FileCount <= Finish
try
close all
% Keep variables above and also keep video in case you want to preload it 
% (see PreloadedVideo below). 
clearvars -except Video FileCount File Input ErrorCount ErrVids ... 
    RatFilter PawFilter BGCase Finish TrialIDName Editor CentroidVelocity ...
    BottomNose TopRatFilter BottomRatFilter

% Pull out variables from "Input" cell array.  Description of these
% variabled are located in the "Input_Setup.m" file.

Batch = Input.Batch;

XStart = Input.XParameters(1);
XEnd = Input.XParameters(2);

FrameStart = Input.FrameParameters(1);
FrameEnd = Input.FrameParameters(2);

VidFPS = Input.VidFPS;

FloorZCoordinate = Input.ZCoordinates(1);  
ArenaZCoordinate = Input.ZCoordinates(2);

TrackerMinimumRatSize = Input.RatSize(1);
FSTOMinimumRatSize = Input.RatSize(2);

Parallax = Input.Parallax;

HeaderYN = Input.Header;

Header = Input.HeaderPixels;

FooterYN = Input.Footer;

Footer = Input.FooterPixels;

TailCutterYN = Input.TailCutter;

Rodent = Input.Rodent;

FSTOFilter = Input.FSTOFilter;

ConcatenateVideos = Input.ConcatenateVideos;

EDGARTrack = Input.EDGAR;

PlotOption = Input.Display;

FigShow = Input.OutputFigs;

PreloadedVideo = Input.VideoPreload;

% Correct BGcase and Editor variables for capitalization.
switch BGCase  
    case 'rat'
        BGCase = 'Rat';
    case 'paw'
        BGCase = 'Paw';
    case 'both'
        BGCase = 'Both';
    case 'none'
        BGCase = 'None';
    otherwise
        % Do nothing
end 
   
switch Editor  
    case 'run'
        Editor = 'Run';
    case 'edit'
        Editor = 'Edit';
    otherwise
        % Do nothing
end
%% AGATHA Start %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% This is needed for the multiselect.  Always put the file in this format.
File = cellstr(File); 

% VideoName - use the full root for best results.
VideoName = File{FileCount};

% Break up filename into path, name, and extension.
% TrialIDName - Files associated with this run will be saved with this 
% label. You can set this to be part of the video name, but then videos 
% need to be saved with a very consistent labeling pattern.  
% Running batches, it's typically easier to pass a label.
% Here, we pull TrialIDName from the filename. 
[~,TrialIDName,~] = fileparts(VideoName); 
TrialIDName(TrialIDName == '.' ) = [];
    
%% File Read-in Section %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

close all
disp(['AGATHA_v2 Running -- ',TrialIDName]);
disp(['Figures will be saved with the header -- ',TrialIDName]);

% This section looks to see if the target video is even in the MATLAB root 
% directory, then makes mock-up names if the video was split into multiple 
% files (something that can happen with certain high-speed settings).  
% Most of the time only 1 video exists, so the last case is the only 
% condition that exists, a simple video read (i.e. if only 1 video exists 
% per trial, only v1 will be used).  If up to 5 files are used to save a 
% certain video, this section of code will concatenate this 5 videos 
% together into a single file.
if PreloadedVideo == 'N'
    clear Video
    disp (' ');
    disp('Loading video... 1-2 minutes processing time');
    
% Uncomment the following block if your camera does not save videos in
% series of smaller files. Comment out the lines between "start comment"
% and "end comment". This is a temporary fix before creating a working case
% in InputSetup -BYMJ 3/15/18

%     if exist('VideoName','var')
%         v1 = VideoName; 
%         v1 = VideoReader(v1);  
%         Video = read(v1);
%     end

% start comment
    if exist('VideoName','var')
        v1 = VideoName;
        if strcmp(ConcatenateVideos,'Y')
            VideoName(end-4) = '1';
            v2 = VideoName;
            VideoName(end-4) = '2';
            v3 = VideoName;
            VideoName(end-4) = '3';
            v4 = VideoName;
            VideoName(end-4) = '4';
            v5 = VideoName;
        end
    else
        disp('Error - Video does not exist within the directory');
    end
    if strcmp(ConcatenateVideos,'Y')
        if exist(v5,'file')
            v1 = VideoReader(v1);
            v2 = VideoReader(v2);
            v3 = VideoReader(v3);
            v4 = VideoReader(v4);
            v5 = VideoReader(v5);
            Vid1 = read(v1);
            Vid2 = read(v2);
            Vid3 = read(v3);
            Vid4 = read(v4);
            Vid5 = read(v5);
            Video = cat(4,Vid1,Vid2,Vid3,Vid4,Vid5);
        elseif exist(v4,'file')
            v1 = VideoReader(v1);
            v2 = VideoReader(v2);
            v3 = VideoReader(v3);
            v4 = VideoReader(v4);
            Vid1 = read(v1);
            Vid2 = read(v2);
            Vid3 = read(v3);
            Vid4 = read(v4);
            Video = cat(4,Vid1,Vid2,Vid3,Vid4);
        elseif exist(v3,'file')
            v1 = VideoReader(v1);
            v2 = VideoReader(v2);
            v3 = VideoReader(v3);
            Vid1 = read(v1);
            Vid2 = read(v2);
            Vid3 = read(v3);
            Video = cat(4,Vid1,Vid2,Vid3);
        elseif exist(v2,'file')
            v1 = VideoReader(v1);
            v2 = VideoReader(v2);
            Vid1 = read(v1);
            Vid2 = read(v2);
            Video = cat(4,Vid1,Vid2);
        else
            v1 = VideoReader(v1);  
            Video = read(v1);
        end
    else
        v1 = VideoReader(v1);  
        Video = read(v1);
    end
% end comment    

    % Video is now stored in the variable Video, so we clear the workspace 
    % of large, unnecessary variables
    clear v1 v2 v3 v4 v5 Vid1 Vid2 Vid3 Vid4 Vid5
    disp('Video Loaded');
    disp(' ');
end

% Cut header if needed.
if HeaderYN == 'Y' && FooterYN == 'N'
    Video = Video(Header:end,:,:,:);
end

% Cut footer if needed.
if FooterYN == 'Y' && HeaderYN == 'N'
    Video = Video(1:Footer,:,:,:);
end

% Cut header and footer if needed.
if FooterYN == 'Y' && HeaderYN == 'Y'
    Video = Video(Header:Footer,:,:,:);
end

% Cut header and footer if needed.
if FooterYN == 'N' && HeaderYN == 'N'
    Video = Video;
end

% ZMAX is the height of the video (1280 x 1080 video will have a ZMAX of 1080).
% XMAX is the height of the video (1280 x 1080 video will have a XMAX of 1280).
% colorchannel is not used, but needs to be called in order to get frames.
% FrameMAX is the number of frames in the video.
[ZMax, XMax, ~, FrameMax] = size(Video);

% Safety: If you messed up XStart somehow, reset it to 1.
if XStart <= 1 || XStart >= XEnd
    XStart = 1;
end
XStart = round(XStart);

% If Xend = 0, set it to XMAX.
% Also, safety: If you messed up XEnd somehow, reset it to XMAX.
if (XEnd == 0) || (XEnd >= XMax) || (XEnd <= XStart) || (XEnd <= 100)  
    XEnd = XMax;
end
XEnd = round(XEnd);

% If Xend = 0, set it to XMAX.
% Also, safety: If you messed up Xend somehow, reset it to XMAX.
if (FrameEnd == 0) || (FrameEnd >= FrameMax) || (FrameEnd <= FrameStart) || (FrameEnd <= 100)  
    FrameEnd = FrameMax;
end
FrameEnd = round(FrameEnd);

% Safety: If you messed up FrameStart somehow, reset it to 1.
if FrameStart < 1 || FrameStart >= FrameEnd
    FrameStart = 1;
end
FrameStart = round(FrameStart);


%% Construct the two possible background images and choose background %%%%%
% This section uses the first and last frame of the video to reconstruct
% the background for the video.

% For sideview
TopFirstFrame = Video(1:FloorZCoordinate,:,:,1);
TopEndFrame = Video(1:FloorZCoordinate,:,:,FrameMax);
Background1 = [TopFirstFrame(:,1:floor(XMax/2),:,:),TopEndFrame(:,(floor(XMax/2)+1):XMax,:,:)];
Background2 = [TopEndFrame(:,1:floor(XMax/2),:,:),TopFirstFrame(:,(floor(XMax/2)+1):XMax,:,:)];

% Picks the best background based upon the consistency of the image.
% Background that doesn't have the rat eliminated should have a higher
% variability in the red, green, and blue channels.
RedVariability = std(std(double(Background1(:,:,1)))) - std(std(double(Background2(:,:,1))));
GreenVariability = std(std(double(Background1(:,:,2)))) - std(std(double(Background2(:,:,2))));
BlueVariability = std(std(double(Background1(:,:,3)))) - std(std(double(Background2(:,:,3))));
if (RedVariability < 0) && (GreenVariability < 0) && (BlueVariability < 0)
    TopBackground = Background1;
elseif (RedVariability > 0) && (GreenVariability < 0) && (BlueVariability < 0)
    TopBackground = Background1;
elseif (RedVariability < 0) && (GreenVariability > 0) && (BlueVariability < 0)
    TopBackground = Background1;
elseif (RedVariability < 0) && (GreenVariability < 0) && (BlueVariability > 0)
    TopBackground = Background1;
else
    TopBackground = Background2;
end
clear Background1 Background2

% For underneath view
BottomFirstFrame = Video(ArenaZCoordinate:ZMax,:,:,1);
BottomEndFrame = Video(ArenaZCoordinate:ZMax,:,:,FrameMax);
Background1 = [BottomFirstFrame(:,1:floor(XMax/2),:,:),BottomEndFrame(:,(floor(XMax/2)+1):XMax,:,:)];
Background2 = [BottomEndFrame(:,1:floor(XMax/2),:,:),BottomFirstFrame(:,(floor(XMax/2)+1):XMax,:,:)];

% Picks the best background based upon the consistency of the image.
% Background that doesn't have the rat eliminated should have a higher
% variability in the red, green, and blue channels.
RedVariability = std(std(double(Background1(:,:,1)))) - std(std(double(Background2(:,:,1))));
GreenVariability = std(std(double(Background1(:,:,2)))) - std(std(double(Background2(:,:,2))));
BlueVariability = std(std(double(Background1(:,:,3)))) - std(std(double(Background2(:,:,3))));
if (RedVariability < 0) && (GreenVariability < 0) && (BlueVariability < 0)
    BottomBackground = Background1;
elseif (RedVariability > 0) && (GreenVariability < 0) && (BlueVariability < 0)
    BottomBackground = Background1;
elseif (RedVariability < 0) && (GreenVariability > 0) && (BlueVariability < 0)
    BottomBackground = Background1;
elseif (RedVariability < 0) && (GreenVariability < 0) && (BlueVariability > 0)
    BottomBackground = Background1;
else
    BottomBackground = Background2;
end

if strcmp(PlotOption,'ShowAll') || strcmp(PlotOption,'DisplayBackground') 
    figure(1); set(gcf, 'position', [0 1080 XMax FloorZCoordinate]); imshow(TopBackground);
end
clear Background1 Background2

% For Paws
PawsFirstFrame = Video(1:ZMax,:,:,1);
PawsEndFrame = Video(1:ZMax,:,:,FrameMax);
Background1 = [PawsFirstFrame(:,1:floor(XMax/2),:,:),PawsEndFrame(:,(floor(XMax/2)+1):XMax,:,:)];
Background2 = [PawsEndFrame(:,1:floor(XMax/2),:,:),PawsFirstFrame(:,(floor(XMax/2)+1):XMax,:,:)];

% Picks the best background based upon the consistency of the image.
% Background that doesn't have the rat eliminated should have a higher
% variability in the red, green, and blue channels.
RedVariability = std(std(double(Background1(:,:,1)))) - std(std(double(Background2(:,:,1))));
GreenVariability = std(std(double(Background1(:,:,2)))) - std(std(double(Background2(:,:,2))));
BlueVariability = std(std(double(Background1(:,:,3)))) - std(std(double(Background2(:,:,3))));
if (RedVariability < 0) && (GreenVariability < 0) && (BlueVariability < 0)
    PawsBackground = Background1;
elseif (RedVariability > 0) && (GreenVariability < 0) && (BlueVariability < 0)
    PawsBackground = Background1;
elseif (RedVariability < 0) && (GreenVariability > 0) && (BlueVariability < 0)
    PawsBackground = Background1;
elseif (RedVariability < 0) && (GreenVariability < 0) && (BlueVariability > 0)
    PawsBackground = Background1;
else
    PawsBackground = Background2;
end

if strcmp(PlotOption,'ShowAll') || strcmp(PlotOption,'DisplayPawBackground') 
    figure(2); imshow(PawsBackground);
end
    
clear Background1 Background2 RedVariability GreenVariability ...
    BlueVariability TopFirstFrame TopEndFrame BottomFirstFrame ...
    BottomEndFrame PawsFirstFrame PawsEndFrame 

% If the Editor variable = 'Run', then go through FSTO
% calculations frame by frame. 
switch Editor
    case 'Run'
%% Direction Tracker Section %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This section of the code determines which direction the rat is walking - 
% left or right.

% Vector of 10 still frame numbers, selected from across the video. The 
% first frame should be the start of the gait trial and the last frame 
% should be near the end.  If there are a lot of frames where the animal is
% off the screen or not moving (at either the start or the end), you need 
% to adjust FrameStart and FrameEnd.
FrameDifference = FrameEnd - FrameStart;
DirectionTrackerArray = [FrameStart, floor(FrameStart + FrameDifference*1/9), ...
    floor(FrameStart + FrameDifference*2/9), floor(FrameStart + FrameDifference*3/9), ...
    floor(FrameStart + FrameDifference*4/9), floor(FrameStart + FrameDifference*5/9), ...
    floor(FrameStart + FrameDifference*6/9), floor(FrameStart + FrameDifference*7/9), ...
    floor(FrameStart + FrameDifference*8/9), FrameEnd];

AssumedRatArea = 0;     RatAreaSizeCounter = 0;

% Preallocate x-coordinate matrix.
RatXCoordinate = zeros(length(DirectionTrackerArray));

for j = 1:length(DirectionTrackerArray)
    Frame = Video(1:FloorZCoordinate,:,:,DirectionTrackerArray(j));
    
    % Cases to determine whether background should be subtracted before
    % running filter or not.
    switch BGCase
        case 'Rat'
            Frame = Frame - TopBackground;    
            % When you subtract the background from the original image, the
            % new background is not perfectly black [0 0 0].  To correct for this,
            % set all pixels < 10 to 0. 
            Frame(Frame(:,:) < 10) = 0;
        case 'Paw'
            % Do nothing. 
        case 'Both'
            Frame = Frame - TopBackground;
            % When you subtract the background from the original image, the
            % new background is not perfectly black [0 0 0].  To correct for this,
            % set all pixels < 10 to 0. 
            Frame(Frame(:,:) < 10) = 0;
        case 'None'
            % Do nothing. 
        otherwise
            fprintf('BGcase incorrectly defined');
    end
        
    % Create mask based on chosen histogram thresholds.
    [~,FilteredRat] = TopRatFilter(Frame);
   
    % Sets non-zero items to white.
    FilteredRat(FilteredRat(:,:) > 0) = 255;
       
    % Erodes followed by dilates to get rid of background noise.
    FilteredRat = imerode(FilteredRat,strel('square',3));
    FilteredRat = imdilate(FilteredRat,strel('square',3));
    FilteredRat = rgb2gray(FilteredRat);
 
    % If the minimum pixel size for the Rat is exceeded, label the image, 
    % select the largest area, ignore all other areas
    if sum(sum(FilteredRat)) > TrackerMinimumRatSize
        LabeledRat = bwlabel(FilteredRat);
        TopStats = regionprops(LabeledRat, 'Area'); 
        AllArea = [TopStats.Area]';
        FilteredRat(LabeledRat ~= find(AllArea == max(AllArea))) = 0;

        % Once only one area is selected, then relable, find centroid, and
        % record x_coordinate of the centroid.
        LabeledRat = bwlabel(FilteredRat);
        TopStats = regionprops(LabeledRat, 'Centroid');
        RatXCoordinate(j) = TopStats.Centroid(1);
    else
        % If there are not a 100 pixels labeled as the rat, then label the
        % centroid as negative.
        RatXCoordinate(j) = -1;
    end
    
    % Redefine FilteredRat as the labeled image from above. 
    FilteredRat = LabeledRat;
    
    % Partially sets the rat size criteria.
    % Loop through middle 20% of video (based on Direction Tracker frame 
    % array above)
    if (j >= 4) && (j <= 6) 
        AssumedRatArea = AssumedRatArea + sum(sum(FilteredRat));
        RatAreaSizeCounter = RatAreaSizeCounter + 1;
        TopRatColumnSum = sum(FilteredRat);
        if (TopRatColumnSum(1) > 1) || (TopRatColumnSum(XMax) > 1)
            disp('Potential Error in Rat Size Calculator.');
            disp('Either Tail or Nose is off the Screen in middle 20% of the Video');
            if FigShow == 'N'
                figure('visible','off'); imshow(FilteredRat);
            else
                figure(3); imshow(FilteredRat);
            end
            Filename_ErrorImages = [TrialIDName, num2str(j), '_Error Image.jpg'];
            Fig = gcf;
            Fig.InvertHardcopy = 'off';
            saveas(gcf,Filename_ErrorImages);
            disp(' ');
        end
    end
    
    % Plotting section for Direction Tracker
    if strcmp(PlotOption,'ShowAll') || strcmp(PlotOption,'DisplayDirectionTracker') 
        figure(4); imshow(Frame);
        figure(5); imshow(FilteredRat);
        hold on
        if RatXCoordinate(j) > 0
            plot(TopStats.Centroid(1),TopStats.Centroid(2),'ro');
        end
        hold off
    end   
end

% This parameter is SUPER DUPER IMPORTANT.  Used to set the size criteria
% for the foot in later sections.  Examines the rat size in 3 frames from
% the middle 20% of the video.  Sets the rat size based on an average of
% these three frames.  From this, we scale most other parameters - paw
% print size, foot size in the side plane, etc.
% Rat size based on 3 middle frames.
AvgRatArea = AssumedRatArea/RatAreaSizeCounter; 
fprintf(['Rat is ', int2str(AvgRatArea), ' pixels in size \n']); 

% Which Direction is the Rat Moving
Counter = 1;
for k = 2:length(RatXCoordinate)
    if (RatXCoordinate(k - 1) > 0) && (RatXCoordinate(k) > 0)
        XDirectionArray(Counter) =  RatXCoordinate(k) - RatXCoordinate(k-1);
	Counter = Counter + 1;
    end
end
XDirection = zeros(Counter - 1,1)';
XDirection(XDirectionArray > 0) = 1;
if sum(XDirection) > Counter/2
    Direction = 'R';
    DirectionNum = 0;
    fprintf('Rat is walking left to right. \n \n');
else
    Direction = 'L';
    DirectionNum = 1;
    fprintf('Rat is walking right to left. \n \n');
end

clear XDirection Counter XDirectionArray XRatCoordinate j k FilteredRat ...
    LabeledRat Frame

%% Analyze Top View and Create the FSTO (foot-strike toe-off) Image %%%%%%%

disp('Creating FSTO Image');

% Pre-allocate FSTO variable.
FSTO = zeros(FrameEnd,XMax); 

% Create threshold to remove the tail in the tail cutting sequence.
TailCutter = round((AvgRatArea/1000)*0.685, 0);

% Assumed width of the foot in the side view based on the size of the
% animal.
FootHeight = round(AvgRatArea/Rodent,0); 
NoseCutter = round((AvgRatArea/1000)*0.5,0);

% Preallocate matrices.
Empty = zeros(FrameEnd,2);
BottomCentroidVelocity = Empty;       TopCentroid = Empty;
BottomCentroid = Empty;         TopNose = Empty;        BottomNose = Empty;

%Set up wait bar
wb = waitbar(0,'1','Name','GAITOR Suite',...
            'CreateCancelBtn',...
            'setappdata(gcbf,''canceling'',1)');
setappdata(wb,'canceling',0)

for j = 1:FrameEnd
    % This only kicks out a little bit of text so that you know the program
    % is still running once it gets into this loop.
    
    % Check for Cancel button press
    if getappdata(wb,'canceling')
        break
    end
    
    %fill wait bar
    waitbar(j / FrameEnd,wb,sprintf('%s','Creating FSTO...')); 
    
   
    % TOP FSTO FILTERING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Creates the possible images that will be filtered to find the rat.
    TopFrame = Video(1:FloorZCoordinate,:,:,j);
    
    % Cases to determine whether background should be subtracted before
    % running filter or not.
    switch BGCase
        case 'Rat'
            TopFrame = TopFrame - TopBackground;    
            % When you subtract the background from the original image, the
            % new background is not perfectly black [0 0 0].  To correct 
            % for this, set all pixels < 10 to 0. 
            TopFrame(TopFrame(:,:) < 10) = 0;
        case 'Paw'
            % Do Nothing.
        case 'Both'
            TopFrame = TopFrame - TopBackground;   
            % When you subtract the background from the original image, the
            % new background is not perfectly black [0 0 0].  To correct 
            % for this, set all pixels < 10 to 0. 
            TopFrame(TopFrame(:,:) < 10) = 0;
        case 'None'
            % Do Nothing.
        otherwise
            fprintf('BGcase incorrectly defined');
    end
   
    % Create mask based on chosen histogram thresholds.
    [~,TopFilteredRat] = TopRatFilter(TopFrame);
    
    % Sets non-zero items to white.
    TopFilteredRat(TopFilteredRat(:,:) > 0) = 255;
    
    % The rat image is eroded followed by dilation to get rid of background 
    % noise.
    % Sometimes it helps to increase the erode/dilate to 4, or flip the
    % order. Dilate then erode. 
    TopFilteredRat = imerode(TopFilteredRat,strel('square',3));
    TopFilteredRat = imdilate(TopFilteredRat,strel('square',3));
    TopFilteredRat = rgb2gray(TopFilteredRat);  
    
    % If the minimum pixel size for the Rat is exceeded (user defined at 
    % start), then, label the image, select the largest area, ignore all 
    % other areas
    if sum(sum(TopFilteredRat)) > TrackerMinimumRatSize
        TopLabeledRat = bwlabel(TopFilteredRat);
        TopStats = regionprops(TopLabeledRat, 'Area'); 
        TopArea = [TopStats.Area]';
        MaxTop = find(TopArea == max(TopArea));
        TopLabeledRat(TopLabeledRat ~= MaxTop(1)) = 0;
    else
        TopLabeledRat(TopFilteredRat == 1) = 0;
    end
    
    % Redefine FilteredRat as the labeled image from above.
    TopFilteredRat = logical(TopLabeledRat);
    
    % BOTTOM FSTO FILTERING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    BottomFrame = Video(ArenaZCoordinate:ZMax,:,:,j);
    
    % Cases to determine whether background should be subtracted before
    % running filter or not.
    switch BGCase
        case 'Rat'
            BottomFrame = BottomFrame - BottomBackground;
            % When you subtract the background from the original image, the
            % new background is not perfectly black [0 0 0].  To correct 
            % for this, set all pixels < 10 to 0.     
            BottomFrame(BottomFrame(:,:) < 10) = 0;
        case 'Paw'
            % Do nothing.
        case 'Both'
            BottomFrame = BottomFrame - BottomBackground;
            % When you subtract the background from the original image, the
            % new background is not perfectly black [0 0 0].  To correct 
            % for this, set all pixels < 10 to 0.     
            BottomFrame(BottomFrame(:,:) < 10) = 0;
        case 'None'
            % Do nothing.
        otherwise
            fprintf('BGcase incorrectly defined');
    end
    
       % Create mask based on chosen histogram thresholds
    [~,BottomFilteredRat] = BottomRatFilter(BottomFrame);
    
    % Sets non-zero items to white.
    BottomFilteredRat(BottomFilteredRat(:,:) > 0) = 255;
    
    % The rat image is eroded followed by dilation to get rid of background 
    % noise.
    BottomFilteredRat = imerode(BottomFilteredRat,strel('square',3));
    BottomFilteredRat = imdilate(BottomFilteredRat,strel('square',3));
    BottomFilteredRat = rgb2gray(BottomFilteredRat);

    % If the minimum pixel size for the Rat is exceeded (user defined at 
    % start), then, label the image, select the largest area, ignore all 
    % other areas
    if sum(sum(BottomFilteredRat)) > TrackerMinimumRatSize
        BottomLabeledRat = bwlabel(BottomFilteredRat);
        BottomStats = regionprops(BottomLabeledRat, 'Area'); 
        BottomArea = [BottomStats.Area]';
        MaxBottom = find(BottomArea == max(BottomArea));
        BottomFilteredRat(BottomLabeledRat ~= MaxBottom(1)) = 0;
    else
        BottomFilteredRat(BottomFilteredRat == 1) = 0;
    end
    
    % Redefine FilteredRat as the labeled image from above.
    BottomFilteredRat = logical(BottomFilteredRat);
    
    % Continued Filtering of Top and Bottom Frames %%%%%%%%%%%%%%%%%%%%%%%%
    
    % Find the Area and Centroid of the Rat
    TopRatStruct = regionprops(TopFilteredRat, 'Centroid');
    TopCentroidVelocity(j,:) = [TopRatStruct.Centroid(1),  TopRatStruct.Centroid(2)];
    BottomRatStruct = regionprops(BottomFilteredRat, 'Centroid');
    BottomCentroidVelocity(j,:) = [BottomRatStruct.Centroid(1),  BottomRatStruct.Centroid(2)];
    
    % ColumnSum is used to determine all x-coordinates that include some
    % portion of the rat.
    TopRatColumnSum = sum(TopFilteredRat);
    BottomRatColumnSum = sum(BottomFilteredRat);
    
    % Always remove the tail
    if TailCutterYN == 'N'
        % TOP ONLY
        % Identifies an X-coordinate that could be the tail.
        TopTailColumns = find(TopRatColumnSum < TailCutter);  
        if Direction == 'L'
            % Eliminates X-coordiates in-front of centroid are ignored.
            TopTailColumns(TopTailColumns < TopRatStruct.Centroid(1)) = 1;  
        else
            % Eliminates X-coordiates in-front of centroid are ignored.
            TopTailColumns(TopTailColumns > TopRatStruct.Centroid(1)) = XMax;  
        end
        
        % Delete tail in any x-coordinate that is still labeled as tail.
        TopFilteredRat(:,TopTailColumns) = 0; 

        % BOTTOM ONLY
        % Identifies an X-coordinate that could be the tail.
        BottomTailColumns = find(BottomRatColumnSum < TailCutter);  
        if Direction == 'L'
            % Eliminates X-coordiates in-front of centroid are ignored.
            BottomTailColumns(BottomTailColumns < BottomRatStruct.Centroid(1)) = 1;  
        else
            % Eliminates X-coordiates in-front of centroid are ignored.
            BottomTailColumns(BottomTailColumns > BottomRatStruct.Centroid(1)) = XMax;  
        end
        
        % Deletes tail in any x-coordinate that is still labeled as tail.
        BottomFilteredRat(:,BottomTailColumns) = 0; 
    end
       
    % Check if the rat's nose or torso are on the screen - or all of the rat.
    % TOP ONLY: We do not find where the bottom rat is on screen anymore -
    % we find bottom centroid and nose potition based on TopRatOnScreen. 
    if Direction == 'L'
        if (TopRatColumnSum(XMax) ~= 0) && (TopRatColumnSum(XMax) > NoseCutter) || ...
                (TopRatColumnSum(1) ~= 0) && (TopRatColumnSum(1) > TailCutter) || ...
                (sum(TopRatColumnSum) > AvgRatArea/2) 
           TopRatOnScreen = 1;
        else
           TopRatOnScreen = 0;
        end
    else 
        if (TopRatColumnSum(1) ~= 0) && (TopRatColumnSum(1) > NoseCutter) || ...
                (TopRatColumnSum(XMax) ~= 0) && (TopRatColumnSum(XMax) > TailCutter) || ...
                (sum(TopRatColumnSum) > AvgRatArea/2)
           TopRatOnScreen = 1;
        else
           TopRatOnScreen = 0;
        end
    end
    
    % Now that tail is eliminated, relabel the rat, calculate area, and
    % eliminate all areas that are not part of the largest area (assumed to
    % be the rat).  
    if TopRatOnScreen == 1
        TopLabeledRat = bwlabel(TopFilteredRat);
        TopStats = regionprops(TopLabeledRat, 'Area'); 
        TopAllArea = [TopStats.Area]';
        MaxTop = find(TopAllArea == max(TopAllArea));
        TopFilteredRat(TopLabeledRat ~= MaxTop(1)) = 0;
        
        % Fix was put in here to take 1st instance of a "max" object in
        % case of 2 same-sized objects.
        BottomLabeledRat = bwlabel(BottomFilteredRat);
        BottomStats = regionprops(BottomLabeledRat, 'Area'); 
        BotomAllArea = [BottomStats.Area]';
        MaxBottom = find(BotomAllArea == max(BotomAllArea));
        BottomFilteredRat(BottomLabeledRat ~= MaxBottom(1)) = 0;
    else
        TopFilteredRat(:,:) = 0;
        BottomFilteredRat(:,:) = 0;
    end
    
    % Find the Nose and Centroid
    if TopRatOnScreen == 1
        if Direction == 'L'
            TopNoseX = min(find(TopRatColumnSum > 0));
            BottomNoseX = min(find(BottomRatColumnSum > 0));
            if TopNoseX < 2  
                % Don't let nose be defined as edge of screen
                TopNoseX = 0;  
                BottomNoseX = 0;
            end
        else
            TopNoseX = max(find(TopRatColumnSum > 0));
            BottomNoseX = max(find(BottomRatColumnSum > 0));
            if TopNoseX > XMax - 2
                % Don't let nose be defined as edge of screen
                TopNoseX = 0;  
                BottomNoseX = 0;
            end
        end
        
        if TopNoseX ~= 0
            TopNoseYArray = TopFilteredRat(:,TopNoseX);
            TopNoseY = round(median(find(TopNoseYArray > 0)),0);
            TopStats = regionprops(TopLabeledRat, 'Centroid'); 
            TopCentroid(j,:) = TopStats.Centroid;
            
            BottomNoseYArray = BottomFilteredRat(:,BottomNoseX);
            BottomNoseY = round(median(find(BottomNoseYArray > 0)),0);
            BottomStats = regionprops(BottomLabeledRat, 'Centroid'); 
            BottomCentroid(j,:) = BottomStats.Centroid;
            
        else
            TopCentroid(j,:) = [0 0];
            TopNoseX = 0;
            TopNoseY = 0;

            BottomCentroid(j,:) = [0 0];
            BottomNoseX = 0;
            BottomNoseY = 0; 
        end
    else
        TopCentroid(j,:) = [0 0];
        TopNoseX = 0;
        TopNoseY = 0;
        
        BottomCentroid(j,:) = [0 0];
        BottomNoseX = 0;
        BottomNoseY = 0;
    end
    TopNose(j,:) = [TopNoseX TopNoseY];
    BottomNose(j,:) = [BottomNoseX BottomNoseY];
    
    % Find the floor and create foot-floor contact row for FSTO %%%%%%%%%%%
    
    FSTORow = zeros(1,XMax); 
    if TopRatOnScreen == 1
        if sum(sum(TopFilteredRat)) > FSTOMinimumRatSize
            % Looks for floor of the animal based on a rowsum.
            RatRowSum = sum(TopFilteredRat'); 
            
            % Pixel associated with the lowest row of the rat ('Real
            % Floor').
            RealFloor = max(find(RatRowSum > 0)); 
            
            % These are the pixels that we will look at to determine 
            % foot-floor contact.
            FloorFootPixels = TopFilteredRat(RealFloor - FootHeight:RealFloor,:); 
            FindFeet = sum(FloorFootPixels);
            FSTORow(FindFeet > FootHeight/2) = 1;
        else
            FloorFootPixels = TopFilteredRat(FloorZCoordinate - FootHeight*3:FloorZCoordinate,:);
            FindFeet = sum(FloorFootPixels);
            FSTORow(FindFeet > FootHeight/2) = 1;
        end
    end
    
    % Nose Cutter
    % Sideview Only (don't cut nose in bottom view - not necessary).
    if Direction == 'L'
        NosePosition = min(find(TopRatColumnSum > 0)); 
        
        % If the rat's nose is on the screen...
        if NosePosition > 1 
            FSTORow(:,NosePosition:NosePosition + NoseCutter) = 0;
            TopFilteredRat(:,NosePosition:NosePosition + NoseCutter) = 0;
        end
    else
        NosePosition = max(find(TopRatColumnSum > 0));
        
        % If the rat's nose is on the screen...
        if NosePosition < XMax 
            FSTORow(:,NosePosition - NoseCutter:NosePosition) = 0;
            TopFilteredRat(:,NosePosition - NoseCutter:NosePosition) = 0;
        end
    end
    FSTO(j,:) = FSTORow(1,:);
      
    % Plotting section %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
     
    if strcmp(PlotOption,'ShowAll') || strcmp(PlotOption,'DisplayFSTOCalculation')
        figure(4); imshow(TopFrame);
        figure(5); imshow(TopFilteredRat);
        hold on
        if TopNose(j,1) ~= 0
            plot(TopNose(j,1),TopNose(j,2),'ro');
            plot(TopCentroid(j,1),TopCentroid(j,2),'go');
        end
        hold off
        
        figure(6); imshow(BottomFrame);
        figure(7); imshow(BottomFilteredRat);
        hold on
        if BottomNose(j,1) ~= 0
            plot(BottomNose(j,1),BottomNose(j,2),'ro');
            plot(BottomCentroid(j,1),BottomCentroid(j,2),'go');
        end
        hold off
    end
    
end
disp('100% Complete');
disp(' ');

delete(wb) 

% Erode the FSTO image to remove noise, then redilate.  Then dilate,
% erode, and fill to clean up FSTO objects.
FSTO = imerode(FSTO,strel('square',3));
FSTO = imdilate(FSTO,strel('square',3));
FSTO = imdilate(FSTO,strel('square',3));
FSTO = imerode(FSTO,strel('square',3));
FSTO = imfill(FSTO);

%% Clean up and plot FSTO image %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Label FSTO Image.
LabeledFSTO = bwlabel(FSTO);

% Save the raw FSTO image for comparison. This is helpful to check
% your RGB filtered/cleaned-up FSTO image to make sure it didn't filter out
% something you wanted. 
figure('visible','off'); imshow(LabeledFSTO);
Filename_FSTOraw = [TrialIDName,'_FSTO_raw.jpg'];
Fig = gcf;
Fig.InvertHardcopy = 'off';
saveas(gcf,Filename_FSTOraw);
RawFSTO = LabeledFSTO;

% Criteria for Inclusion as FTSO Object - Find Bounding Box.
FSTOStats = regionprops(LabeledFSTO, 'BoundingBox', 'Centroid');
FSTOBounds = [FSTOStats.BoundingBox];
FSTOCentroid = [FSTOStats.Centroid];

% Automatically filter FSTO objects if FSTOFilter = 'Y'.
if FSTOFilter == 'Y'
    % NOTE: Increasing from 1500 makes your "too small" filter less 
    % restrictive, ie narrower objects are accepted as viable steps. 
    % (ex objects 15 pixels wide and below are rejected is now 10 wide and
    % below). 1500 was selected based on trial and error. It has been 
    % stable, but can be adjusted as needed. 
    FSTOObjectWidth = round(AvgRatArea/1500);

    % NOTE: when adjusting q: decreasing q causes and increase in 
    % "HeightAdj" which makes your "too short" filter more restrictive, 
    % ie the upper bound of the range of too short objects is increased 
    % (ex objects from 0-12 pixels rejected is now 0-24 pixel objects 
    % rejected) decreasing q ALSO causes your "too tall" filter to become 
    % more restrictive, ie the lower bound of the range of too tall object 
    % is now even lower. (ex objects 48+ pixels tall are rejected is now 
    % 38+ pixel objects rejected).

    %You can change q; DO NOT change HeightAdj, we want to preserve the 
    %current ratio. 
    q = 0.667; 
    HeightAdj = 0.05/q;
    FSTOObjectHeight = round(VidFPS*HeightAdj);

    % Remove Areas that are Too Narrow - Size/Width.
    % 'BoundingBox' gives width as 3rd number in vector.
    FSTOBoundsWidth = FSTOBounds(3:4:end); 
    TooNarrow = find(FSTOBoundsWidth < FSTOObjectWidth);
    for i = 1:length(TooNarrow)
        LabeledFSTO(LabeledFSTO == TooNarrow(i)) = 0;
    end

    % Remove Areas that are Too Wide - Size/Width.
    TooWide = find(FSTOBoundsWidth > FSTOObjectWidth*5);
    for i = 1:length(TooWide)
        LabeledFSTO(LabeledFSTO == TooWide(i)) = 0;
    end

    % % Remove Areas that are Too Short - fps/Height. 
    % % 'BoundingBox' gives height as 4th number in vector.
    FSTOBoundsHeight = FSTOBounds(4:4:end);
    TooShort = find(FSTOBoundsHeight < FSTOObjectHeight);
    for i = 1:length(TooShort)
        LabeledFSTO(LabeledFSTO == TooShort(i)) = 0;
    end

    % Remove Areas that are Too Tall - fps/Height  (animal not moving).
    TallHeightAdj = 12*q;
    TooTall = find(FSTOBoundsHeight > FSTOObjectHeight*TallHeightAdj);
    for i = 1:length(TooTall)
        LabeledFSTO(LabeledFSTO == TooTall(i)) = 0;
    end

    % Crop FSTO image based on Xstart & Xend (defined at the beginning).
    % 'Centroid' gives x coord as 1st number in vector.
    FSTOCentroidX = FSTOCentroid(1:2:end); 
    for i = 1:max(max(LabeledFSTO))
        if isnan(FSTOCentroidX(i))
            FSTOCentroidX(i) = 1;
        end
        if FSTOCentroidX(i) <= XStart
            LabeledFSTO(:,1:round(FSTOCentroidX(i))) = 0;
        end
        if FSTOCentroidX(i) >= XEnd
            LabeledFSTO(:,round(FSTOCentroidX(i)):end) = 0;
        end  
    end

    % Re-label FSTO Image.
    LabeledFSTO = bwlabel(LabeledFSTO);
    FSTOStats = regionprops(LabeledFSTO, 'Centroid', 'Extrema');
end

% Bind and Fill Objects With Near-Proximity Centroids.
for i = 2:max(max(LabeledFSTO))
    Dist = sqrt( (FSTOStats(i).Centroid(1)-FSTOStats(i-1).Centroid(1))^2 + ...
        (FSTOStats(i).Centroid(2)-FSTOStats(i-1).Centroid(2))^2 );
    if Dist < (AvgRatArea/5500)
        if FSTOStats(i).Centroid(1) > FSTOStats(i-1).Centroid(1)
            LabeledFSTO(round(FSTOStats(i).Extrema(9),0),round((FSTOStats(i).Extrema(1)-Dist),0): ...
                round(FSTOStats(i).Extrema(1),0)) = i;
            LabeledFSTO(round(FSTOStats(i).Extrema(14),0),round((FSTOStats(i).Extrema(1)-Dist),0): ...
                round(FSTOStats(i).Extrema(1),0)) = i;
        end
    end
end

% Fill FSTO Image.
LabeledFSTO = imfill(LabeledFSTO);

% Re-label FSTO Image.
LabeledFSTO = bwlabel(LabeledFSTO);
FSTOStats = regionprops(LabeledFSTO, 'Centroid', 'Extrema');

% Preallocate FSTOData variable. 
FSTOData = zeros(max(max(LabeledFSTO)),8);

% Create Black & White FSTO Image.
for i = 1:max(max(LabeledFSTO))
    if Direction == 'L'
        if FSTOStats(i).Extrema(10)-0.5 > 1 && FSTOStats(i).Extrema(14)-0.5 < FrameEnd
            FS = [FSTOStats(i).Extrema(2)-0.5,FSTOStats(i).Extrema(10)-0.5];
            TO = [FSTOStats(i).Extrema(6)-0.5,FSTOStats(i).Extrema(14)-0.5];
            ObjCent = [FSTOStats(i).Centroid(1),FSTOStats(i).Centroid(2)];
        else
            FS = [0,0];
            TO = [0,0];
            ObjCent = [0,0];
            LabeledFSTO(LabeledFSTO == LabeledFSTO(i)) = 0;
        end
    else
        if FSTOStats(i).Extrema(9)-0.5 > 1 && FSTOStats(i).Extrema(13)-0.5 < FrameEnd
            FS = [FSTOStats(i).Extrema(1)-0.5,FSTOStats(i).Extrema(9)-0.5];
            TO = [FSTOStats(i).Extrema(5)-0.5,FSTOStats(i).Extrema(13)-0.5];
            ObjCent = [FSTOStats(i).Centroid(1),FSTOStats(i).Centroid(2)];
        else
            FS = [0,0];
            TO = [0,0];
            ObjCent = [0,0];
            LabeledFSTO(LabeledFSTO == LabeledFSTO(i)) = 0;
        end
    end
    FSTOData(i,:) = [i,0,FS,TO,ObjCent];
end

FSTOData = sortrows(FSTOData, 3);
RealFSTOObjs = find(FSTOData(:,3) > 0);
FSTOData = FSTOData(min(RealFSTOObjs):max(RealFSTOObjs),:);

% Define Fore and Hind Paws and Locate X Coordinate for Finding Paws.
FSTOObjCentroid(:,1:2) = FSTOData(:,7:8);
CentroidBetas = polyfit(FSTOObjCentroid(:,1),FSTOObjCentroid(:,2),1);
XSpace = linspace(1,XMax);
CentroidLine = CentroidBetas(2)+CentroidBetas(1)*XSpace;

% Define Fore and Hind Paws.
BlueLabeledFSTO = LabeledFSTO;      RedLabeledFSTO = LabeledFSTO;
for i = 1:length(FSTOData(:,1))
    if FSTOData(i,7) ~= 0
        ObjResidual = FSTOData(i,8) - (CentroidBetas(2) + CentroidBetas(1)*FSTOData(i,7));
        if ObjResidual < 0
            FSTOData(i,2) = 1; % ForeLimb = 1
            BlueLabeledFSTO(BlueLabeledFSTO == FSTOData(i,1)) = 200;    
        else
            FSTOData(i,2) = 0; % HindLimb = 0
            RedLabeledFSTO(RedLabeledFSTO == FSTOData(i,1)) = 200;
        end
    end
end

% Create RGB version of FSTO Image.
FSTOOnes = ones(FrameEnd,XMax);
FSTORGB = cat(3, RedLabeledFSTO, FSTOOnes, BlueLabeledFSTO);
FSTORGB = uint8(FSTORGB);
FSTORGB(FSTORGB ~= 200) = 0;

if FigShow == 'N'
    figure('visible','off'); imshow(FSTORGB);
else
    figure(9); imshow(FSTORGB);
end          
hold on

% Adjust number text position for visibility. If single digit (<10), adjust
% x-position by 4 & if double digit, adjust by 10 from centroid.
for i = 1:length(FSTOData(:,1))
    if FSTOData(i,1) < 10
        text(FSTOData(i,7)-4,FSTOData(i,8),int2str(FSTOData(i,1)), 'Color', 'white');
    else
        text(FSTOData(i,7)-10,FSTOData(i,8),int2str(FSTOData(i,1)), 'Color', 'white');
    end
    plot(FSTOData(i,3),FSTOData(i,4),'co');
    plot(FSTOData(i,5),FSTOData(i,6),'mo');
end 

plot(XSpace,CentroidLine,'yellow');
hold off
Filename_FSTO2 = [TrialIDName,'_FSTO_RGB.jpg'];
Fig = gcf;
Fig.InvertHardcopy = 'off';
saveas(gcf,Filename_FSTO2);

% Save the raw FSTO matrix in the FSTOStruct variable.  This is only used
% later if you need to run in Edit mode.  
FSTOStruct = struct('ImageMat',RawFSTO,'Direction',Direction,'AvgRatArea',AvgRatArea);
save([TrialIDName, 'FSTOStruct.mat'],'FSTOStruct');

fprintf('FSTO Image Saved. \n');

%% START EDIT MODE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % If Editor = Edit, then skip all FSTO calculations above.  Start here
    % and load FSTOStruct. Call FSTOEditor, then proceed to recalculate
    % pawprints below. 
    case 'Edit' 
        load([TrialIDName, 'FSTOStruct.mat']);
        FSTO = FSTOStruct.ImageMat;
        Direction = FSTOStruct.Direction;
        AvgRatArea = FSTOStruct.AvgRatArea;
        
        Comp = strcmp(Direction,'L');
        if Comp == 1
            DirectionNum = 1;
        else
            DirectionNum = 0;
        end
        
        [FSTOData] = FSTOEditor(FSTO,Direction,TrialIDName);
        
        LoadDATAName = [TrialIDName, '_DATA.mat'];
        if exist(LoadDATAName,'file') == 1    
            load(LoadDataName);
            BottomCentroidVelocity = DATA.Velocity.BottomCentroidVelocity;
            % If Error encountered here, comment out TopCentroidVelocity load
            % and TopNose load; older versions of AGATHAv2 did not collect and
            % save these data. DATA.Velocity.BottomCentroidVelocity will also need to be changed to DATA.Velocity.CentroidVelocity -BYMJ 3/15/18
            TopCentroidVelocity = DATA.Velocity.TopCentroidVelocity;
            BottomNose = DATA.Velocity.BottomNoseVelocity;
            % Old versions will need DATA.Velocity.NoseVelocity loaded above -
            % BYMJ 3/19/18
            TopNose = DATA.Velocity.TopNoseVelocity;
        else
            % Try to recalculate the velocity data
            % Create threshold to remove the tail and nose in the cutting sequences.
            TailCutter = round((AvgRatArea/1000)*0.685, 0);
            NoseCutter = round((AvgRatArea/1000)*0.5,0);

            % Preallocate matrices.
            Empty = zeros(FrameEnd,2);
            BottomCentroidVelocity = Empty; TopCentroid = Empty;
            BottomCentroid = Empty;         TopNose = Empty;        BottomNose = Empty;
            
            for j = 1:FrameEnd

                % TOP RAT FILTERING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

                % Creates the possible images that will be filtered to find the rat.
                TopFrame = Video(1:FloorZCoordinate,:,:,j);

                % Cases to determine whether background should be subtracted before
                % running filter or not.
                switch BGCase
                    case 'Rat'
                        TopFrame = TopFrame - TopBackground;    
                        % When you subtract the background from the original image, the
                        % new background is not perfectly black [0 0 0].  To correct 
                        % for this, set all pixels < 10 to 0. 
                        TopFrame(TopFrame(:,:) < 10) = 0;
                    case 'Paw'
                        % Do Nothing.
                    case 'Both'
                        TopFrame = TopFrame - TopBackground;   
                        % When you subtract the background from the original image, the
                        % new background is not perfectly black [0 0 0].  To correct 
                        % for this, set all pixels < 10 to 0. 
                        TopFrame(TopFrame(:,:) < 10) = 0;
                    case 'None'
                        % Do Nothing.
                    otherwise
                        fprintf('BGcase incorrectly defined');
                end

                % Create mask based on chosen histogram thresholds.
                [~,TopFilteredRat] = TopRatFilter(TopFrame);

                % Sets non-zero items to white.
                TopFilteredRat(TopFilteredRat(:,:) > 0) = 255;

                % The rat image is eroded followed by dilation to get rid of background 
                % noise.
                % Sometimes it helps to increase the erode/dilate to 4, or flip the
                % order. Dilate then erode. 
                TopFilteredRat = imerode(TopFilteredRat,strel('square',3));
                TopFilteredRat = imdilate(TopFilteredRat,strel('square',3));
                TopFilteredRat = rgb2gray(TopFilteredRat);  

                % If the minimum pixel size for the Rat is exceeded (user defined at 
                % start), then, label the image, select the largest area, ignore all 
                % other areas
                if sum(sum(TopFilteredRat)) > TrackerMinimumRatSize
                    TopLabeledRat = bwlabel(TopFilteredRat);
                    TopStats = regionprops(TopLabeledRat, 'Area'); 
                    TopArea = [TopStats.Area]';
                    MaxTop = find(TopArea == max(TopArea));
                    TopLabeledRat(TopLabeledRat ~= MaxTop(1)) = 0;
                else
                    TopLabeledRat(TopFilteredRat == 1) = 0;
                end

                % Redefine FilteredRat as the labeled image from above.
                TopFilteredRat = logical(TopLabeledRat);

                % BOTTOM RAT FILTERING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

                BottomFrame = Video(ArenaZCoordinate:ZMax,:,:,j);

                % Cases to determine whether background should be subtracted before
                % running filter or not.
                switch BGCase
                    case 'Rat'
                        BottomFrame = BottomFrame - BottomBackground;
                        % When you subtract the background from the original image, the
                        % new background is not perfectly black [0 0 0].  To correct 
                        % for this, set all pixels < 10 to 0.     
                        BottomFrame(BottomFrame(:,:) < 10) = 0;
                    case 'Paw'
                        % Do nothing.
                    case 'Both'
                        BottomFrame = BottomFrame - BottomBackground;
                        % When you subtract the background from the original image, the
                        % new background is not perfectly black [0 0 0].  To correct 
                        % for this, set all pixels < 10 to 0.     
                        BottomFrame(BottomFrame(:,:) < 10) = 0;
                    case 'None'
                        % Do nothing.
                    otherwise
                        fprintf('BGcase incorrectly defined');
                end

                % Create mask based on chosen histogram thresholds
                [~,BottomFilteredRat] = BottomRatFilter(BottomFrame);

                % Sets non-zero items to white.
                BottomFilteredRat(BottomFilteredRat(:,:) > 0) = 255;

                % The rat image is eroded followed by dilation to get rid of background 
                % noise.
                BottomFilteredRat = imerode(BottomFilteredRat,strel('square',3));
                BottomFilteredRat = imdilate(BottomFilteredRat,strel('square',3));
                BottomFilteredRat = rgb2gray(BottomFilteredRat);

                % If the minimum pixel size for the Rat is exceeded (user defined at 
                % start), then, label the image, select the largest area, ignore all 
                % other areas
                if sum(sum(BottomFilteredRat)) > TrackerMinimumRatSize
                    BottomLabeledRat = bwlabel(BottomFilteredRat);
                    BottomStats = regionprops(BottomLabeledRat, 'Area'); 
                    BottomArea = [BottomStats.Area]';
                    MaxBottom = find(BottomArea == max(BottomArea));
                    BottomFilteredRat(BottomLabeledRat ~= MaxBottom(1)) = 0;
                else
                    BottomFilteredRat(BottomFilteredRat == 1) = 0;
                end

                % Redefine FilteredRat as the labeled image from above.
                BottomFilteredRat = logical(BottomFilteredRat);

                % Find the Area and Centroid of the Rat
                TopRatStruct = regionprops(TopFilteredRat, 'Centroid');
                TopCentroidVelocity(j,:) = [TopRatStruct.Centroid(1),  TopRatStruct.Centroid(2)];
                BottomRatStruct = regionprops(BottomFilteredRat, 'Centroid');
                BottomCentroidVelocity(j,:) = [BottomRatStruct.Centroid(1),  BottomRatStruct.Centroid(2)];

                % ColumnSum is used to determine all x-coordinates that include some
                % portion of the rat.
                TopRatColumnSum = sum(TopFilteredRat);
                BottomRatColumnSum = sum(BottomFilteredRat);

                % Always remove the tail
                if TailCutterYN == 'N'
                    % TOP ONLY
                    % Identifies an X-coordinate that could be the tail.
                    TopTailColumns = find(TopRatColumnSum < TailCutter);  
                    if Direction == 'L'
                        % Eliminates X-coordiates in-front of centroid are ignored.
                        TopTailColumns(TopTailColumns < TopRatStruct.Centroid(1)) = 1;  
                    else
                        % Eliminates X-coordiates in-front of centroid are ignored.
                        TopTailColumns(TopTailColumns > TopRatStruct.Centroid(1)) = XMax;  
                    end

                    % Delete tail in any x-coordinate that is still labeled as tail.
                    TopFilteredRat(:,TopTailColumns) = 0; 

                    % BOTTOM ONLY
                    % Identifies an X-coordinate that could be the tail.
                    BottomTailColumns = find(BottomRatColumnSum < TailCutter);  
                    if Direction == 'L'
                        % Eliminates X-coordiates in-front of centroid are ignored.
                        BottomTailColumns(BottomTailColumns < BottomRatStruct.Centroid(1)) = 1;  
                    else
                        % Eliminates X-coordiates in-front of centroid are ignored.
                        BottomTailColumns(BottomTailColumns > BottomRatStruct.Centroid(1)) = XMax;  
                    end

                    % Deletes tail in any x-coordinate that is still labeled as tail.
                    BottomFilteredRat(:,BottomTailColumns) = 0; 
                end

                % Check if the rat's nose or torso are on the screen - or all of the rat.
                % TOP ONLY: We do not find where the bottom rat is on screen anymore -
                % we find bottom centroid and nose potition based on TopRatOnScreen. 
                if Direction == 'L'
                    if (TopRatColumnSum(XMax) ~= 0) && (TopRatColumnSum(XMax) > NoseCutter) || ...
                            (TopRatColumnSum(1) ~= 0) && (TopRatColumnSum(1) > TailCutter) || ...
                            (sum(TopRatColumnSum) > AvgRatArea/2) 
                       TopRatOnScreen = 1;
                    else
                       TopRatOnScreen = 0;
                    end
                else 
                    if (TopRatColumnSum(1) ~= 0) && (TopRatColumnSum(1) > NoseCutter) || ...
                            (TopRatColumnSum(XMax) ~= 0) && (TopRatColumnSum(XMax) > TailCutter) || ...
                            (sum(TopRatColumnSum) > AvgRatArea/2)
                       TopRatOnScreen = 1;
                    else
                       TopRatOnScreen = 0;
                    end
                end

                % Now that tail is eliminated, relabel the rat, calculate area, and
                % eliminate all areas that are not part of the largest area (assumed to
                % be the rat).  
                if TopRatOnScreen == 1
                    TopLabeledRat = bwlabel(TopFilteredRat);
                    TopStats = regionprops(TopLabeledRat, 'Area'); 
                    TopAllArea = [TopStats.Area]';
                    MaxTop = find(TopAllArea == max(TopAllArea));
                    TopFilteredRat(TopLabeledRat ~= MaxTop(1)) = 0;

                    % Fix was put in here to take 1st instance of a "max" object in
                    % case of 2 same-sized objects.
                    BottomLabeledRat = bwlabel(BottomFilteredRat);
                    BottomStats = regionprops(BottomLabeledRat, 'Area'); 
                    BotomAllArea = [BottomStats.Area]';
                    MaxBottom = find(BotomAllArea == max(BotomAllArea));
                    BottomFilteredRat(BottomLabeledRat ~= MaxBottom(1)) = 0;
                else
                    TopFilteredRat(:,:) = 0;
                    BottomFilteredRat(:,:) = 0;
                end

                % Find the Nose and Centroid
                if TopRatOnScreen == 1
                    if Direction == 'L'
                        TopNoseX = min(find(TopRatColumnSum > 0));
                        BottomNoseX = min(find(BottomRatColumnSum > 0));
                        if TopNoseX < 2  
                            % Don't let nose be defined as edge of screen
                            TopNoseX = 0;  
                            BottomNoseX = 0;
                        end
                    else
                        TopNoseX = max(find(TopRatColumnSum > 0));
                        BottomNoseX = max(find(BottomRatColumnSum > 0));
                        if TopNoseX > XMax - 2
                            % Don't let nose be defined as edge of screen
                            TopNoseX = 0;  
                            BottomNoseX = 0;
                        end
                    end

                    if TopNoseX ~= 0
                        TopNoseYArray = TopFilteredRat(:,TopNoseX);
                        TopNoseY = round(median(find(TopNoseYArray > 0)),0);
                        TopStats = regionprops(TopLabeledRat, 'Centroid'); 
                        TopCentroid(j,:) = TopStats.Centroid;

                        BottomNoseYArray = BottomFilteredRat(:,BottomNoseX);
                        BottomNoseY = round(median(find(BottomNoseYArray > 0)),0);
                        BottomStats = regionprops(BottomLabeledRat, 'Centroid'); 
                        BottomCentroid(j,:) = BottomStats.Centroid;

                    else
                        TopCentroid(j,:) = [0 0];
                        TopNoseX = 0;
                        TopNoseY = 0;

                        BottomCentroid(j,:) = [0 0];
                        BottomNoseX = 0;
                        BottomNoseY = 0; 
                    end
                else
                    TopCentroid(j,:) = [0 0];
                    TopNoseX = 0;
                    TopNoseY = 0;

                    BottomCentroid(j,:) = [0 0];
                    BottomNoseX = 0;
                    BottomNoseY = 0;
                end
                TopNose(j,:) = [TopNoseX TopNoseY];
                BottomNose(j,:) = [BottomNoseX BottomNoseY];
            end
        end        
        delete([TrialIDName, '__DATA.mat']);
end 

%% Find Paw Prints %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

PawImages = PawsBackground(ArenaZCoordinate:ZMax,1:XMax);
PawImages(:,:,1) = 1;   PawImages(:,:,2) = 1;   PawImages(:,:,3) = 1;
ForePawImages = im2bw(PawImages);       HindPawImages = im2bw(PawImages);

% Define paw # & Fore/Hind - same as FSTO.
PawPrintData(:,1) = FSTOData(:,1);      PawPrintData(:,2) = FSTOData(:,2);  

for i = 1:length(FSTOData(:,1))
    % Account for Parallax & Set Up Window to Look for Paw
    % Get x-coordinate from FSTO as initial guess.
    XPawCoordinate = FSTOData(i,3);  
    
    % If paw is on the left side of screen.
    if XPawCoordinate < XMax/2  
        XPawCenter = XPawCoordinate + round(((XMax/2) - XPawCoordinate)*Parallax,0);
        XPawMin = XPawCenter-round(AvgRatArea/750,0);
        XPawMax = XPawCenter+round(AvgRatArea/750,0);
    else 
        XPawCenter = XPawCoordinate - round((XPawCoordinate - (XMax/2))*Parallax,0);
        XPawMin = XPawCenter-round(AvgRatArea/750,0);
        XPawMax = XPawCenter+round(AvgRatArea/750,0);
    end
    
    % Safety Value for XPawMin and XPawMax.
    if XPawMin < 1
        XPawMin = 1;
    end
    if XPawMax > XMax
        XPawMax = XMax;
    end
    
    % Stance time is found in order to determine how long to run the
    % filter.
    StanceTime = FSTOData(i,6) - FSTOData(i,4);
    
    % Find Background for Paw
    PawPrintBackground = PawsBackground(ArenaZCoordinate:ZMax,XPawMin:XPawMax,:);
    
    % This identifies the frame that is 20% of stance and finds the paw.
    j = (FSTOData(i,4) + round(StanceTime*.2,0));
    
    % FOREPAWS ONLY
    if PawPrintData(i,2) == 1 % Forepaw
        ForePawPrint = Video(ArenaZCoordinate:ZMax,XPawMin:XPawMax,:,j-1);
        
        % Cases to determine whether background should be subtracted before
        % running filter or not.
        switch BGCase
            case 'Rat'
                % Do nothing
            case 'Paw'
                ForePawPrint = ForePawPrint - PawPrintBackground;       
                % When you subtract the background from the original image, the
                % new background is not perfectly black [0 0 0].  To correct this,
                % set all pixels < 10 to 0.  
                ForePawPrint(ForePawPrint(:,:) < 10) = 0;
            case 'Both'
                ForePawPrint = ForePawPrint - PawPrintBackground;     
                % When you subtract the background from the original image, the
                % new background is not perfectly black [0 0 0].  To correct this,
                % set all pixels < 10 to 0.  
                ForePawPrint(ForePawPrint(:,:) < 10) = 0;
            case 'None'
                % Do nothing
            otherwise
                fprintf('BGcase incorrectly defined');
        end
        

        % Create mask based on chosen histogram thresholds.
        [~,ForePawPrint] = PawFilter(ForePawPrint);

        % Sets non-zero items to white.
        ForePawPrint(ForePawPrint(:,:) > 0) = 255;
        
        % Additional background noise reduction. If any RGB channel = 0, 
        % set the whole pixel to [0 0 0].
        for h = 1:size(ForePawPrint,1)
            for hh = 1:size(ForePawPrint,2)
                if (ForePawPrint(h,hh,1) == 0 || ForePawPrint(h,hh,2) == 0 || ForePawPrint(h,hh,3) == 0)
                    ForePawPrint(h,hh,:) = 0; 
                end
            end
        end

        ForePawPrint = rgb2gray(ForePawPrint);  

        % Select the largest area (the paw), ignore all other areas.
        LabeledPawFinal = bwlabel(ForePawPrint);
        PawStats = regionprops(LabeledPawFinal, 'Area'); 
        PawArea = [PawStats.Area]';
        MaxPaw = find(PawArea == max(PawArea));
        LabeledPawFinal(LabeledPawFinal ~= MaxPaw(1)) = 0;
        ForePawPrint = LabeledPawFinal;

        if strcmp(PlotOption,'ShowAll') || strcmp(PlotOption,'DisplayPawPrint') 
            figure(10);
            title('Forepaw Tracker')
            subplot(1,3,1)
            drawnow
            imshow(ForePawPrint);
            subplot(1,3,2)
            drawnow
            imshow(ForePawPrint);
            subplot(1,3,3)
            drawnow
            imshow(ForePawPrint);
        end  

        LabeledForePawPrint = ForePawPrint;
        ForePawPrintID = MaxPaw;
   
    else
        % HINDPAWS ONLY
        HindPawPrint = Video(ArenaZCoordinate:ZMax,XPawMin:XPawMax,:,j-1);
        
        % Cases to determine whether background should be subtracted before
        % running filter or not.
        switch BGCase
            case 'Rat'
                % Do nothing
            case 'Paw'
                HindPawPrint = HindPawPrint - PawPrintBackground;
                % When you subtract the background from the original image, the
                % new background is not perfectly black [0 0 0].  To correct this,
                % set all pixels < 10 to 0.  
                HindPawPrint(HindPawPrint(:,:) < 10) = 0;

            case 'Both'
                HindPawPrint = HindPawPrint - PawPrintBackground;
                HindPawPrint = HindPawPrint - PawPrintBackground;
                % When you subtract the background from the original image, the
                % new background is not perfectly black [0 0 0].  To correct this,
                % set all pixels < 10 to 0.  
                HindPawPrint(HindPawPrint(:,:) < 10) = 0;
            case 'None'
                % Do nothing
            otherwise
                fprintf('BGcase incorrectly defined');
        end

        
        % Create mask based on chosen histogram thresholds
        [~,HindPawPrint] = PawFilter(HindPawPrint);
    
        % Sets non-zero items to white.
        HindPawPrint(HindPawPrint(:,:) > 0) = 255;
        
        for h = 1:size(HindPawPrint,1)
            for hh = 1:size(HindPawPrint,2)
                if (HindPawPrint(h,hh,1) == 0 || HindPawPrint(h,hh,2) == 0 || HindPawPrint(h,hh,3) == 0)
                    HindPawPrint(h,hh,:) = 0; 
                end
            end
        end

        HindPawPrint = rgb2gray(HindPawPrint);

        LabeledPawFinal = bwlabel(HindPawPrint);
        PawStats = regionprops(LabeledPawFinal, 'Area'); 
        PawArea = [PawStats.Area]';
        MaxPaw = find(PawArea == max(PawArea));
        LabeledPawFinal(LabeledPawFinal ~= MaxPaw(1)) = 0;
        HindPawPrint = LabeledPawFinal;

        if strcmp(PlotOption,'ShowAll') || strcmp(PlotOption,'DisplayPawPrint') 
            figure(11);
            title('Hindpaw Tracker')
            subplot(1,3,1)
            drawnow
            imshow(HindPawPrint);
            subplot(1,3,2)
            drawnow
            imshow(HindPawPrint);
            subplot(1,3,3)
            drawnow
            imshow(HindPawPrint);
        end
        LabeledHindPawPrint = HindPawPrint;
        HindPawPrintID = MaxPaw;
    end
 
    % Find Paw Location.
    % FOREPAW ONLY
     if PawPrintData(i,2) == 1 % Forepaw
        ForePawPrintStats = regionprops(LabeledForePawPrint, 'Centroid');
        ForePawWidth = size(LabeledForePawPrint,2);
        ForePawXPosition = XPawCenter + (ForePawPrintStats(ForePawPrintID).Centroid(1) - (ForePawWidth/2));
        ForePawLoc(i,2:3) = [ForePawXPosition,ForePawPrintStats(ForePawPrintID).Centroid(2)];    
        ForePawLoc(i,1) = PawPrintData(i,1);
        
        % Create Paw Print Image
        LabeledForePaw2 = bwlabel(LabeledForePawPrint);
        ForePawImages(:,XPawMin:XPawMax) =  ForePawImages(:,XPawMin:XPawMax) + LabeledForePaw2; 
        ForePawPrintStats2 = regionprops(ForePawImages, 'BoundingBox');
        PawPrintData(i,4) = ForePawLoc(i,2);
        PawPrintData(i,5) = ForePawLoc(i,3);        
     else
        % HINDPAW ONLY
        HindPawPrintStats = regionprops(LabeledHindPawPrint, 'Centroid');
        HindPawPrintWidth = size(LabeledHindPawPrint,2);
        HindPawXPosition = XPawCenter + (HindPawPrintStats(HindPawPrintID).Centroid(1) - (HindPawPrintWidth/2));
        HindPawLoc(i,2:3) = [HindPawXPosition,HindPawPrintStats(HindPawPrintID).Centroid(2)];
        HindPawLoc(i,1) = PawPrintData(i,1);
        
        % Create Paw Print Image
        LabeledHindPaw2 = bwlabel(LabeledHindPawPrint);
        HindPawImages(:,XPawMin:XPawMax) = HindPawImages(:,XPawMin:XPawMax) + LabeledHindPaw2;
        HindPawPrintStats2 = regionprops(HindPawImages, 'BoundingBox');
        PawPrintData(i,4) = HindPawLoc(i,2);
        PawPrintData(i,5) = HindPawLoc(i,3);
     end
     
     if PawPrintData(i,2) == 1
         f = length(ForePawPrintStats2);
         ForeBounds(i,1) = PawPrintData(i,1);
         ForeBounds(i,2:5) = [ForePawPrintStats2(f).BoundingBox(1), ...
             ForePawPrintStats2(f).BoundingBox(2), ForePawPrintStats2(f).BoundingBox(3), ...
             ForePawPrintStats2(f).BoundingBox(4)];
     else
         h = length(HindPawPrintStats2);
         HindBounds(i,1) = PawPrintData(i,1);
         HindBounds(i,2:5) = [HindPawPrintStats2(h).BoundingBox(1), ...
             HindPawPrintStats2(h).BoundingBox(2), HindPawPrintStats2(h).BoundingBox(3), ...
             HindPawPrintStats2(h).BoundingBox(4)]; 
     end        
end

%% Determine if Paw is Left or Right %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% FOREPAWS ONLY
ForePawLocLR = ForePawLoc;
% Removing rows of zeros to leave only forepaw rows.
ForePawLocLR(all(ForePawLocLR == 0,2),:) = [];  

% 0 = Right Foot, 1 = Left Foot.
for i = 1:(length(ForePawLocLR(:,1)))
    if i == 1
        ForePawLocLR(i,5) = nan;
        if Direction == 'L'
            ForePawLocLR(i,4) = ForePawLocLR(i,3) > ForePawLocLR(i+1,3);  
        else
            ForePawLocLR(i,4) = ForePawLocLR(i,3) < ForePawLocLR(i+1,3); 
        end
    elseif i == length(ForePawLocLR(:,1))
        ForePawLocLR(i,5) = nan;
        if Direction == 'L'
            ForePawLocLR(i,4) = ForePawLocLR(i,3) > ForePawLocLR(i-1,3); 
        else
            ForePawLocLR(i,4) = ForePawLocLR(i,3) < ForePawLocLR(i-1,3);
        end
     else
        if Direction == 'L'
            ForePawLocLR(i,4) = ForePawLocLR(i,3) > ForePawLocLR(i-1,3); 
            ForePawLocLR(i,5) = ForePawLocLR(i,3) > ForePawLocLR(i+1,3);
        else
            ForePawLocLR(i,4) = ForePawLocLR(i,3) < ForePawLocLR(i-1,3);
            ForePawLocLR(i,5) = ForePawLocLR(i,3) < ForePawLocLR(i+1,3);
        end
    end
    
    if isnan(ForePawLocLR(i,5)) == 1
        ForePawLocLR(i,6) = ForePawLocLR(i,4);
    elseif ForePawLocLR(i,4) == ForePawLocLR(i,5)
        if ForePawLocLR(i,4) == 0
            ForePawLocLR(i,6) = 0;
        else
            ForePawLocLR(i,6) = 1;
        end
    else
        % 400 means the code can't verify right vs left for this step. 
        % Will need to be manually defined.
        ForePawLocLR(i,6) = 400; 
    end
end
   
% HINDPAWS ONLY
HindPawLocLR = HindPawLoc;
% Removing rows of zeros to leave only hindpaw rows.
HindPawLocLR(all(HindPawLocLR == 0,2),:) = [];  

% 0 = Right Foot, 1 = Left Foot.
for i = 1:(length(HindPawLocLR(:,1)))
    if i == 1
        HindPawLocLR(i,5) = nan;
        if Direction == 'L'
            HindPawLocLR(i,4) = HindPawLocLR(i,3) > HindPawLocLR(i+1,3);  
        else
            HindPawLocLR(i,4) = HindPawLocLR(i,3) < HindPawLocLR(i+1,3);
        end
    elseif i == length(HindPawLocLR(:,1))
        HindPawLocLR(i,5) = nan;
        if Direction == 'L'
            HindPawLocLR(i,4) = HindPawLocLR(i,3) > HindPawLocLR(i-1,3);
        else
            HindPawLocLR(i,4) = HindPawLocLR(i,3) < HindPawLocLR(i-1,3);
        end
     else
        if Direction == 'L'
            HindPawLocLR(i,4) = HindPawLocLR(i,3) > HindPawLocLR(i-1,3);
            HindPawLocLR(i,5) = HindPawLocLR(i,3) > HindPawLocLR(i+1,3); 
        else
            HindPawLocLR(i,4) = HindPawLocLR(i,3) < HindPawLocLR(i-1,3);
            HindPawLocLR(i,5) = HindPawLocLR(i,3) < HindPawLocLR(i+1,3);
        end
    end
    
    if isnan(HindPawLocLR(i,5)) == 1
        HindPawLocLR(i,6) = HindPawLocLR(i,4);
    elseif HindPawLocLR(i,4) == HindPawLocLR(i,5)
        if HindPawLocLR(i,4) == 0
            HindPawLocLR(i,6) = 0;
        else
            HindPawLocLR(i,6) = 1;
        end
    else
        % 400 means the code can't verify right vs left for this step. 
        % Will need to be manually defined.
        HindPawLocLR(i,6) = 400; 
    end
end

% Best guess for unknown (=400) paws. Look to the step before and after the
% unknown step.   
Seek400 = find(ForePawLocLR(:,6) == 400);
for i = 1:length(Seek400)
    Current = ForePawLocLR(Seek400(i),3);
    Before = ForePawLocLR(Seek400(i) - 1,3);
    After = ForePawLocLR(Seek400(i) + 1,3);
    if abs(Before-Current) > abs(After - Current) 
        ForePawLocLR(Seek400,6) = ForePawLocLR(Seek400 + 1,6);
    else
        ForePawLocLR(Seek400,6) = ForePawLocLR(Seek400 - 1,6);
    end
end
clear Seek400 Current Before After

Seek400 = find(HindPawLocLR(:,6) == 400);
for i = 1:length(Seek400)
    Current = HindPawLocLR(Seek400(i),3);
    Before = HindPawLocLR(Seek400(i) - 1,3);
    After = HindPawLocLR(Seek400(i) + 1,3);
    if abs(Before-Current) > abs(After - Current) 
        HindPawLocLR(Seek400,6) = HindPawLocLR(Seek400 + 1,6);
    else
        HindPawLocLR(Seek400,6) = HindPawLocLR(Seek400 - 1,6);
    end
end
    
AllPawLoc = vertcat(ForePawLocLR, HindPawLocLR);
AllPawLoc = sortrows(AllPawLoc,1);

% Sort left/rights to match the order of PawPrint_Data & FSTO_Data. 
% Move the R = 0 and L = 1 data into column 3 of PawPrint_Data.
for i = 1:(length(AllPawLoc(:,1)))
    Row = find(AllPawLoc(i,1) == PawPrintData(:,1));
    PawPrintData(Row,3) = AllPawLoc(i,6);
end  

% Plot Right/Left Paw Images %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if FigShow == 'N'
    figure('visible','off');
else
    figure(12);
end

subplot(2,1,1);
imshow(ForePawImages);
title('Forepaws')
hold on
for i = 1:(length(PawPrintData(:,1)))
    if PawPrintData(i,2) == 1  % Forepaw
        if PawPrintData(i,3) == 0
            text(PawPrintData(i,4) - 4,PawPrintData(i,5),'R', 'Color', 'red');
        else
            text(PawPrintData(i,4) - 4,PawPrintData(i,5),'L', 'Color', 'red');
        end
    end
    hold off
end

subplot(2,1,2)
imshow(HindPawImages);
title('Hindpaws')
hold on
for i = 1:(length(PawPrintData(:,1)))
    if PawPrintData(i,2) == 0  % Hindpaw
        if PawPrintData(i,3) == 0
            text(PawPrintData(i,4)-4,PawPrintData(i,5),'R', 'Color', 'red');
        else
            text(PawPrintData(i,4)-4,PawPrintData(i,5),'L', 'Color', 'red');
        end
    end
end
hold off
truesize

% Save the Left/Right Pawprint Image.
Filename_LRImages = [TrialIDName,'_LRImages.jpg'];
Fig = gcf;
Fig.InvertHardcopy = 'off';
saveas(gcf,Filename_LRImages);

%% Plot Paw Print Images %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Separate into a single subplot with forepaws, all, and hindpaws in
% separate plots.  Also, convert the pawprint image to RGB and label them
% to match the FSTO image. 

% FOREPAWS ONLY
% Create RGB version of Pawprint Image - Forepaws.
for i = 1:length(PawPrintData(:,1))
    BlueLabeledPawPrint = bwlabel(ForePawImages);
    BlueLabeledPawPrint(BlueLabeledPawPrint == PawPrintData(i,1)) = 200;
    PawZeros = zeros(size(BlueLabeledPawPrint,1),size(BlueLabeledPawPrint,2));
    ForePawRGB = cat(3, PawZeros, PawZeros, BlueLabeledPawPrint);
end

if FigShow == 'N'
    figure('visible','off');
else
    figure(13);
end
warning('off','all');

subplot(3,1,1);
imshow(ForePawRGB); 
for i = 1:length(PawPrintData(:,1))
    if PawPrintData(i,2) == 1    % Forepaw   
        if PawPrintData(i,1) < 10
            text(PawPrintData(i,4) - 4,PawPrintData(i,5),int2str(PawPrintData(i,1)), 'Color', 'white');
        else
            text(PawPrintData(i,4) - 10,PawPrintData(i,5),int2str(PawPrintData(i,1)), 'Color', 'white');
        end
    end
end
title('Forepaws Only')
hold on

% ALL PAWS
subplot(3,1,2);
imshow(ForePawImages + HindPawImages);
hold on
for i = 1:length(PawPrintData(:,1))
    hold on
    if PawPrintData(i,1) < 10
        text(PawPrintData(i,4) - 4,PawPrintData(i,5),int2str(PawPrintData(i,1)), 'Color', 'black');
    else
        text(PawPrintData(i,4) - 10,PawPrintData(i,5),int2str(PawPrintData(i,1)), 'Color', 'black');
    end
    hold off
end
title('All Paw Prints')

% HINDPAWS ONLY
% Create RGB version of Pawprint Image - Hindpaws.
for i = 1:length(PawPrintData(:,1))
    RedLabeledPawPrint = bwlabel(HindPawImages);
    RedLabeledPawPrint(RedLabeledPawPrint == PawPrintData(i,1)) = 200;
    PawZeros = zeros(size(RedLabeledPawPrint,1),size(RedLabeledPawPrint,2));
    HindPawRGB = cat(3, RedLabeledPawPrint, PawZeros, PawZeros);
end

subplot(3,1,3);
imshow(HindPawRGB);
hold on
for i = 1:length(PawPrintData(:,1))
    if PawPrintData(i,2) == 0  % Hindpaw
        hold on
        if PawPrintData(i,1) < 10
            text(PawPrintData(i,4) - 4,PawPrintData(i,5),int2str(PawPrintData(i,1)), 'Color', 'white');
        else
            text(PawPrintData(i,4) - 10,PawPrintData(i,5),int2str(PawPrintData(i,1)), 'Color', 'white');
        end
        hold off
    end
end
title('Hindpaws Only')
truesize

% Save Pawprint Images.
Filename_PawPrintImages = [TrialIDName,'_PawPrintImages.jpg'];
Fig = gcf;
Fig.InvertHardcopy = 'off';
saveas(gcf,Filename_PawPrintImages);

fprintf('Paw Images Saved. \n');
 
%% Save the Output Matrices for AGATHA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Output .mat files - these file with be the input to the "calculator" code.

% Below is the old EDGAR Step Tracker. Leave commented out if using new
% tracker.
% if EDGARTrack == 'N'
%     AGATHAData(:,1:8) = FSTOData(:,1:8);
%     AGATHAData(:,9:11) = PawPrintData(:,3:5);
%     AGATHAData(:,12) = DirectionNum;
% else
%     ForeBounds(all(ForeBounds == 0,2),:) = [];
%     HindBounds(all(HindBounds == 0,2),:) = [];
%     AllPawPrintBounds = vertcat(ForeBounds,HindBounds);
%     AllPawPrintBounds = sortrows(AllPawPrintBounds,1);
% 
%     % Sort left/rights to match the order of PawPrint_Data & FSTO_Data. 
%     % Move the R = 0 and L = 1 data into column 3 of PawPrint_Data.
%     for i = 1:(length(AllPawPrintBounds(:,1)))
%         Row = find(AllPawPrintBounds(i,1) == PawPrintData(:,1));
%         PawPrintData(Row,6:9) = AllPawPrintBounds(Row,2:5);
%     end
%     
%     AGATHAData(:,1:8) = FSTOData(:,1:8);
%     AGATHAData(:,9:15) = PawPrintData(:,3:9);
%     AGATHAData(:,16) = DirectionNum;
%      
%     % Run the Step Tracker code from here. 
%     Filename_AGATHAData = [TrialIDName, '_AGATHAData.mat'];
%     EDGARStepTracker(Input,AGATHAData,Filename_AGATHAData);
%     fprintf('EGDAR_StepTracker Complete. \n \n');
% end


% Save all data into one big "AGATHA" matrix.
AGATHAData(:,1:8) = FSTOData(:,1:8);
AGATHAData(:,9:11) = PawPrintData(:,3:5);
AGATHAData(:,12) = DirectionNum;

VelocityStruct = struct('BottomCentroidVelocity',BottomCentroidVelocity,...
    'BottomNoseVelocity',BottomNose,'TopCentroidVelocity',TopCentroidVelocity,'TopNoseVelocity',TopNose);
% Save AGATHA_Data and Velocity_Data into a single structure. 
DATA = struct('AGATHA',AGATHAData,'Velocity',VelocityStruct);
Filename_DATA = [TrialIDName, '_DATA.mat'];
save(Filename_DATA, 'DATA');

fprintf([TrialIDName, ' COMPLETE. \n______________________________ \n\n']);

% Don't try and look at file{2} if you only chose 1 file to begin with.
if length(File) == 1
    break
end

close all;

catch MException
    ErrorLine = MException.stack.line;
    fprintf(['\nERROR encountered in ', TrialIDName, ' at Line: ', '%i', '\n'],ErrorLine);
    ErrorMessage = MException.message;
    disp(ErrorMessage);
    
    ErrVids{ErrorCount,1} = TrialIDName;
    ErrVids{ErrorCount,2} = ErrorLine;
    ErrVids{ErrorCount,3} = ErrorMessage;
    
    ErrorCount = ErrorCount + 1;
    beep

    
    if exist('BottomCentroidVelocity','var') == 1 && exist('TopCentroidVelocity','var') == 1
        if exist('AGATHAData','var') == 0
            AGATHAData = [];
        end
        VelocityStruct = struct('BottomCentroidVelocity',BottomCentroidVelocity,...
            'BottomNoseVelocity',BottomNose,'TopCentroidVelocity',TopCentroidVelocity,'TopNoseVelocity',TopNose);
        % Save AGATHA_Data and Velocity_Data into a single structure. 
        DATA = struct('AGATHA',AGATHAData,'Velocity',VelocityStruct);
        Filename_DATA = [TrialIDName, '_DATA.mat'];
        save(Filename_DATA, 'DATA');
        fprintf([TrialIDName, ' COMPLETE. \n______________________________ \n\n']);
    end
    if exist('wb','var') == 1
        delete(wb) 
    end
end

% Set filecount to address next file in batch.
FileCount = FileCount + 1;
end

% If there were error messages, save them to the directory.
if isempty(ErrVids) == 0
    Filename_BatchErrors = [Batch, '_Errors.mat'];
    save(Filename_BatchErrors, 'ErrVids');
end

close all;


