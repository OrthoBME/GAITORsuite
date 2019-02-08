function InputSetupv2_1

% Must have ginput_RED Matlab code in the path

% Turns off warnings for the session 
warning('off','all')
warning

% Requests user set a summary file name. -BYMJ
prompt = {'Enter desired batch name'};
dlg_title = 'Batch';
num_lines = 1;
defaultans = {'Batch1'};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
Batch = answer{1};

% Give users instruction to select representative video file.
waitfor(msgbox(('Please select the folder containing your video files.'),'Select Directory Help'));
Directory = uigetdir;
waitfor(msgbox({'Please select sample video file.' 'Only select ONE video file.'},'Select Image Help'));
% Select video file to work with
File = uipickfiles('FilterSpec',Directory,'Type',{'*.avi' '.avi'});

% This is needed for the multiselect.  Always put the file in this format.
% This shouldn't matter in this case. Users should only have selected one
% video.
File = cellstr(File); 
% VideoName - use the full root for best results
VideoName = File{1};  

fprintf('Loading video... 1-2 minutes processing time \n \n');
v = VideoReader(VideoName);
Video = read(v);

[~, XMax, ~, FrameMax] = size(Video);
MidFrame = round(FrameMax/2);
fprintf('The number of frames in this video is: %d \n \n',FrameMax);
%% Main Parameters %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Get Z Coordinates
waitfor(msgbox('Select the arena floor by clicking once.'));
imshow(Video(:,:,:,MidFrame));
[~,FloorZCoordinate] = ginput_RED(1);
close all

waitfor(msgbox('Select the back of the arena in the mirrored image by clicking once.'));
imshow(Video(:,:,:,MidFrame));
[~,ArenaZCoordinate] = ginput_RED(1);
close all

% These 'floor' parameters cuts the video into the side view and underneath
% views of the animal walking. See protocol for doing this. 
% 'floor_Zcoordinate' is used to limit the region of interest for the side
% view.  This should be the Zcoordinate associated with the middle or
% bottom half of the acrylic floor.  Do not use the top of the acrylic, as 
% this pixel can move slightly and the foot-strike and toe-off may not be
% identified.  'arena_Zcoordinate' is used to limit the region of interest 
% for the underneath view.  This should be the Zcoordinate associate with 
% the "top" of the acrylic cage in the view from underneath.  Think of it 
% this way - floor_Zcoordinate will include all rows of the image/video 
% from the top (1) to the floor_Zcoordinate.  arena_Zcoordinate
% arena_Zcoordinate will include all row of the image from 
% arena_Zcoordinate to the bottom of the image/video. 
% Zcoordinates = [floor_Zcoordinate arena_Zcoordinate] below.
ZCoordinates = [FloorZCoordinate ArenaZCoordinate];

% Get Parallax
answer = 'No';
defaultans = {'1'};
while strcmp(answer,'Yes') == 0
    % Select frame from which to calculate the parallax correction value.
    % If the frame selected does not show the correct view, allow users to
    % try a different frame.
    prompt = {'Enter frame from which to calculate your parallax correction value. This should be the earliest frame the nose can be seen in both lateral and ventral views.'};
    dlg_title = 'Parallax Calculation Frame';
    num_lines = 1;
    FrameAnswer = inputdlg(prompt,dlg_title,num_lines,defaultans);
    defaultans = {FrameAnswer{1}};
    SelectFrame = str2double(FrameAnswer{1});

    % Display selected frame.
    imshow(Video(:,:,:,SelectFrame));

    opts.Interpreter = 'tex';
    % Include the desired default answer.
    opts.Default = 'Yes';
    quest = 'Is the nose visible on both the lateral and ventral view?';
    answer = questdlg(quest,'Nose Visible',...
                      'Yes','No',opts);
end

waitfor(msgbox('First click on the nose in the lateral view, then click on the nose in the ventral view.'));  
[ParallaxNum,~] = ginput_RED(2);
ParallaxNum2 = abs(ParallaxNum(1) - ParallaxNum(2));
close all

% Parallax allows you to account for distortion off of the mirror
% A typical parallax is 10% or 0.10.
% Pixels of distortion divided by (image width/2)
Parallax = ParallaxNum2/(XMax/2);

% Get X Parameters and Frame Parameters
prompt = {'Enter X Start:','Enter X End:','Enter Frame Start:','Enter Frame End:'};
definput = {'1','0','1','0'};
title = 'X and Frame Parameters';
dims = [1 35];
answer = inputdlg(prompt,title,dims,definput);

XStart = str2double(answer{1});
XEnd = str2double(answer{2});
FrameStart = str2double(answer{3});
FrameEnd = str2double(answer{4});

% Xstart and Xend are the x-coordinates that you want to analyze in the 
% video (region of interest). If Xend = 0, the end point will be set to 
% the farthest pixel to the right. For example, if your video is 1280 wide
% x 1080 tall, and Xstart = 1 and Xend = 0 AGATHA will analyze a region of
% interest starting at 1 and ending at 1280. If you want to shrink your 
% region of interst to start at 100 and end at 950 (due to rat starting or 
% stopping, or some other reason), set Xstart = 100 and Xend = 950.
% XParameters = [XStart XEnd] below.
XParameters = [XStart XEnd];

% FrameStart and FrameEnd define the video frame range you want to analyze
% tduring the Direction Tracker.  If FrameEnd = 0, the end frame will
% be set to the maximum frame for the video.  This is helpful if your video
% isn't cropped well, and there are portions where the animal is
% stopped/not moving.  If the animal is not moving, the Direction Tracker
% is likely to get confused. Thus, crop out those frames with FrameStart
% and FrameEnd. 
% FrameParameters = [FrameStart FrameEnd] below.
FrameParameters = [FrameStart FrameEnd];

% Get FPS
prompt = {'Enter FPS:'};
definput = {'500'};
title = 'Video Recording Rate';
num_lines = 1;
answer = inputdlg(prompt,title,num_lines,definput);

% Declaring the Video Recording Speed 'vid_fps'.  Needed to define the 
% anticipated height of FSTO objects. 
VidFPS = str2double(answer{1});

% Get Animal Parameters
prompt = {'Enter Min Pixels for Rat on Screen:','Enter Min Pixels for Rat on Screen (FSTO):','Enter Species (Mouse/Rat):'};
definput = {'100','10000','Rat'};
title = 'Animal Parameters';
dims = [1 35];
answer = inputdlg(prompt,title,dims,definput);

MinRatSize_Direction = str2double(answer{1});
MinRatSize_FSTO = str2double(answer{2});

% This filter setting sets the lower threshold for how many pixels need to 
% be identified to accept the object as the rat. In other words, a setting 
% of 500 means there needs to be at least one area with 500 pixels in 
% continuous contact or else the rat is assumed to be off the screen
% (MinRatSize_Direction). The value needs to be much higher for FSTO 
% section (MinRatSize_FSTO)... About 60-70% of the total area of the rat.
% RatSize = [MinRatSize_Direction MinRatSize_FSTO] below
RatSize = [MinRatSize_Direction MinRatSize_FSTO];

% Specify species. 'Rat' or 'Mouse'.  Add the necessary if statements to
% set rodent size if you wish to add another species ('Rabbit','Guinea Pig',etc). 
Rodent = answer{3};
if strcmp(Rodent,'Rat') == 1 || strcmp(Rodent,'rat') == 1
    Rodent = 10000;
elseif strcmp(Rodent,'Mouse') == 1 || strcmp(Rodent,'mouse') == 1
    Rodent = 500;
end


%% Video Adjustments %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
opts.Interpreter = 'tex';
% Include the desired default answer.
opts.Default = 'No';
quest = 'Do you want to edit default video adjustment variables?';
answer = questdlg(quest,'Video Adjustments','Yes','No',opts);

if strcmp(answer,'Yes') == 1
    % Get Video Parameters
    prompt = {'Turn on Header Trimmer:','Turn on Footer Trimmer','Turn off Tail Cutter:','Use FSTO Filters:','Concatenate Videos:'};
    definput = {'N','N','N','Y','N'};
    title = 'Video Adjustments';
    dims = [1 35];
    answer = inputdlg(prompt,title,dims,definput);
    
    % If video has a header, remove top x pixel rows from each frame. Default
    % is 'N'. Change to 'Y' if video has a header. Default pixel rows
    % (Input{15}(2)) is 30.
    Header = answer{1};
    if Header == 'Y'
        % Get level for header to remove (remove everything above)
        waitfor(msgbox('Select the level for the header (will remove everything above this).'));
        imshow(Video(:,:,:,MidFrame));
        [~,HeaderPixels] = ginput_RED(1);
        close all
        
        ZCoordinates = [ZCoordinates(1)- HeaderPixels, ZCoordinates(2)- HeaderPixels];
    else
        HeaderPixels = 0;
    end
    if strcmp(Header,'Y') == 1 || strcmp(Rodent,'y') == 1
        Header = 'Y';
    else
        Header = 'N';
    end
    
    % If video has a footer, remove bottom x pixel rows from each frame. Default
    % is 'N'. Change to 'Y' if video has a footer. FooterPixels is the value
    % below which all pixels will be cut off.
    Footer = answer{2};
    if Footer == 'Y'
        % Get level for footer to remove (remove everything below)
        waitfor(msgbox('Select the level for the footer (will remove everything below this).'));
        imshow(Video(:,:,:,MidFrame));
        [~,FooterPixels] = ginput_RED(1);
        close all
    end
    if strcmp(Footer,'Y') == 1 || strcmp(Rodent,'y') == 1
        Footer = 'Y';
    else
        Footer = 'N';
        FooterPixels = 0;
    end
    % Turn off tail cutter. Default is 'N'.  Change to 'Y' to turn off the tail
    % cutter, and keep the tail.
    TailCutter = answer{3};
    if strcmp(TailCutter,'Y') == 1 || strcmp(TailCutter,'y') == 1
        TailCutter = 'Y';
    else
        TailCutter = 'N';
    end
    % FSTO filtering is built into AGATHA.  The code will look for objects that
    % are too short, too tall, too wide, too narrow, etc. Defualt is 'Y'.
    % Change to 'N' if you do not want your FSTO image to be automatically
    % filtered.
    FSTOFilter = answer{4};
    if strcmp(FSTOFilter,'Y') == 1 || strcmp(FSTOFilter,'y') == 1
        FSTOFilter = 'Y';
    else
        FSTOFilter = 'N';
    end
    % Some camera systems will break large videos into smaller chunks.  If so,
    % keep ConcatenateVideos = 'Y'.  This will make the code look for videos of
    % the same name that end in 1, 2, 3, etc... and concatenate them into a
    % single video. However, if you do not need to concatenate videos, then set
    % this parameter to 'N'.
    ConcatenateVideos = answer{5};
    if strcmp(ConcatenateVideos,'Y') == 1 || strcmp(ConcatenateVideos,'y') == 1
        ConcatenateVideos = 'Y';
    else
        ConcatenateVideos = 'N';
    end
else
    Header = 'N';
    HeaderPixels = 0;
    Footer = 'N';
    FooterPixels = 0;
    TailCutter = 'N';
    FSTOFilter = 'Y';
    ConcatenateVideos = 'Y';
end

%% EDGAR Options %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
opts.Interpreter = 'tex';
% Include the desired default answer.
opts.Default = 'No';
quest = 'Do you want to edit default EDGAR settings?';
answer = questdlg(quest,'EDGAR Options','Yes','No',opts);

if strcmp(answer,'Yes') == 1 
    % Get EDGAR Parameters
    opts.Interpreter = 'tex';
    % Include the desired default answer.
    opts.Default = 'Y';
    quest = 'Do you want to turn on the EDGAR Step Tracker?';
    % EDGAR: Change to 'Y' if you want to run EDGAR_StepTracker along side
    % AGATHA
    EDGAR = questdlg(quest,'Step Tracker','Y','N',opts);
    if strcmp(EDGAR,'Y') == 1     
        waitfor(msgbox({'Click on the boundaries of each force panel from left to right.' ...
            'i.e. A AB B C CD D'}));
        imshow(Video(:,:,:,MidFrame));
        [Bounds,~] = ginput(6);
        close all
        % Force plate x locations (min and max) - in pixels (for EDGAR only).
        % PlateBounds = [A AB B C CD D];   x locations in pixels
        PlateBounds = [Bounds(1) Bounds(2) Bounds(3) Bounds(4) Bounds(5) Bounds(6)];
    end
else
    EDGAR = 'N';
    PlateBounds = [0 0 0 0 0 0];
end

%% Troubleshooting and Display Options %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
opts.Interpreter = 'tex';
% Include the desired default answer.
opts.Default = 'No';
quest = 'Do you want to edit default troubleshooting and display variables?';
answer = questdlg(quest,'Troubleshooting and Display Options','Yes','No',opts);

if strcmp(answer,'Yes') == 1 
    % Get Troubleshooting and Display Options
    prompt = {'Display Mode:','Show Output Figures:','Preload Video:'};
    definput = {'Quiet','N','N'};
    title = 'Troubleshooting and Display Options';
    dims = [1 35];
    answer = inputdlg(prompt,title,dims,definput);       
    % PlotOptions section allows you to watch AGATHA work.  Good for trouble 
    % shooting, but if running a batch set to 'Quiet'.
    % 'ShowAll':  Shows all plotting options
    % 'DisplayBackground':  Shows the background image that was selected from
    %       background reconstruction section.
    % 'DisplayDirectionTracker':  Shows the rat moving across the screen in the
    %       direction tracker section.
    % 'DisplayFSTOCalculation':  Shows the rat moving across the screen during 
    %       the creation of the FSTO image.
    Display = answer{1};

    % Show output figures. Change to 'N' if yo do not want to see output images 
    % pop up with each run. 
    OutputFigs = answer{2};

    % If you are trouble shooting on a video, you only need to load it into 
    % MATLAB once.  If the video you are wanting to work with is saved in the 
    % variable 'video', you can set PreloadedVideo to 'Y' and this will bypass
    % the video loading section (saving a few minutes per run).
    % THIS FUNCTIONALITY ONLY OCCURS WITHIN A SCRIPT. YOU WILL BE FORCED TO
    % LOAD VIDEOS REGARDLESS OF WHAT YOU SET THIS TO IF YOU RUN AGATHA AS A
    % FUNCTION.
    VideoPreload = answer{3};
else
    Display = 'Quiet';
    OutputFigs = 'N';
    VideoPreload = 'N';
end

%% Save Input file %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Put all variables into a structure
Input = struct('Batch',Batch,'XParameters',XParameters,'FrameParameters',...
    FrameParameters,'VidFPS',VidFPS,'ZCoordinates',ZCoordinates,...
    'RatSize',RatSize,'Rodent',Rodent,'Parallax',Parallax,'Header',Header,'HeaderPixels',...
    HeaderPixels,'Footer',Footer,'FooterPixels',FooterPixels,'TailCutter',TailCutter,'FSTOFilter',FSTOFilter,...
    'ConcatenateVideos',ConcatenateVideos,'EDGAR',...
    EDGAR,'PlateBounds',PlateBounds,'Display',Display,'OutputFigs',...
    OutputFigs,'VideoPreload',VideoPreload);

Input_Filename = ['Input_',Batch,'.mat'];
save(Input_Filename, 'Input');

%% Create Filter Images %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if Header == 'Y'
    FloorZCoordinate = ZCoordinates(1) + HeaderPixels;
    ArenaZCoordinate = ZCoordinates(2) + HeaderPixels;
else
    FloorZCoordinate = ZCoordinates(1);
    ArenaZCoordinate = ZCoordinates(2);
end
%% Background Construction %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% FOR TOP
TopFirstFrame = (Video(1:FloorZCoordinate,:,:,1));
TopEndFrame = (Video(1:FloorZCoordinate,:,:,FrameMax));

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

% FOR BOTTOM
BottomFirstFrame = (Video(ArenaZCoordinate:end,:,:,1));
BottomEndFrame = (Video(ArenaZCoordinate:end,:,:,FrameMax));

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

%% Save Full Arena Image

% Define im_bottom as middle frame to select filters from.
figure('visible','off'); imshow(Video(:,:,:,MidFrame));
saveas(gcf, [Batch, '_im_full_bg.jpg']) 

%% Isolate Rat (top only)

% % Define im_bottom as middle frame to select filters from.
    if  Header == 'Y'  
        % Save TopMidFrame with header removed
        TopMidFrame = Video(HeaderPixels:FloorZCoordinate,:,:,MidFrame); 
        figure('visible','off'); imshow(TopMidFrame);
        saveas(gcf, [Batch, '_im_rat_bg.jpg']) 
        
        % Redefine TopMidFrame with Header for background subtraction
        TopMidFrame = Video(1:FloorZCoordinate,:,:,MidFrame);
        Top = TopMidFrame - TopBackground;  % remove background

        % Subtracting the background image does not leave a perfect [0 0 0] rgb
        % value.  Therefore, we look for pixels where the color value is < 10 and
        % set them to 0 manually. 
        
        % Save TopMidFrame with header removed and background subtracted
        Top(Top(:,:) < 10) = 0;
        figure('visible','off'); imshow(Top(HeaderPixels:end,:,:));
        saveas(gcf, [Batch, '_im_rat.jpg']) 
    else
        TopMidFrame = Video(1:FloorZCoordinate,:,:,MidFrame); 
        figure('visible','off'); imshow(TopMidFrame);
        saveas(gcf, [Batch, '_im_rat_bg.jpg']) 

        Top = TopMidFrame - TopBackground;  % remove background

        % Subtracting the background image does not leave a perfect [0 0 0] rgb
        % value.  Therefore, we look for pixels where the color value is < 10 and
        % set them to 0 manually. 
        Top(Top(:,:) < 10) = 0;

        figure('visible','off'); imshow(Top);
        saveas(gcf, [Batch, '_im_rat.jpg']) 
    end
        
%% Isolate Paws (bottom only)

% Define im_top as middle frame to select filters from.
    if  Footer == 'Y'  
        % Save TopMidFrame with header removed
        BottomMidFrame = Video(ArenaZCoordinate:FooterPixels,:,:,MidFrame); 
        figure('visible','off'); imshow(BottomMidFrame);
        saveas(gcf, [Batch, '_im_paw_bg.jpg'])
        
        % Redefine TopMidFrame with Header for background subtraction
        BottomMidFrame = Video(ArenaZCoordinate:end,:,:,MidFrame);
        Bottom = BottomMidFrame - BottomBackground;  % remove background

        % Subtracting the background image does not leave a perfect [0 0 0] rgb
        % value.  Therefore, we look for pixels where the color value is < 10 and
        % set them to 0 manually. 
        
        % Save TopMidFrame with header removed and background subtracted
        Bottom(Bottom(:,:) < 10) = 0; 
        figure('visible','off'); imshow(Bottom);
        saveas(gcf, [Batch, '_im_paw.jpg']) 
    else
        BottomMidFrame = Video(ArenaZCoordinate:end,:,:,MidFrame);
        figure('visible','off'); imshow(BottomMidFrame);
        saveas(gcf, [Batch, '_im_paw_bg.jpg'])
        
        Bottom = BottomMidFrame - BottomBackground;  % remove background
        
        % Subtracting the background image does not leave a perfect [0 0 0] rgb
        % value.  Therefore, we look for pixels where the color value is < 10 and
        % set them to 0 manually.
        Bottom(Bottom(:,:) < 10) = 0;
        
        figure('visible','off'); imshow(Bottom);
        saveas(gcf, [Batch, '_im_paw.jpg'])
    end
    
%% Complete input setup
close all;
fprintf('Input setup complete. Please run colorThresholder to continue filter setup. \n \n');

end