# AGATHA-2.0-Suite
Rewritten MATLAB gait analysis code and associated calculators and set-up files. 

Contacts: elakes@ufl.edu or bjacobs@bme.ufl.edu

MATLAB 2014 or newer is required. 
Necessary Matlab Files:
1.	InputSetup 
2.	AGATHAv2
3.	EDGARStepTracker (if doing dynamics)
4.	FSTOEditor
5.	AGATHACalculator
6.	uipickfiles
7.	xlsappend

Run Instructions:
***To begin, ensure all files listed above are in your working directory in MATLAB***
1.	Note: As of 2/20/17, InputSetup is the final portion of the code still under works. We are working on a GUI code to set all the parameters.  For now, use these instructions:
2.	Open InputSetup in Matlab.
    a.	Scroll through the parameters and set them for your experiment. 
    b.	Click “Run”.
    c.	Choose a single video to use for set-up parameters. Since camera angle, height, etc. may change from day to day – you will likely need to run InputSetup for each day of your experiment (unless you are very consistent).
    d.	Immediately after running, type “close all” into the command line, and then type “imshow(Video(:,:,:,MidFrame))”.  Using the cursor button in the figure window, check your FloorZCoordinate and ArenaZCoordinate.  Also, do “imshow(Video(:,:,:,1))” or “imshow(Video(:,:,:,end))” to check the maximum parallax at the edges.  Update InputSetup and rerun.
    e.	The code will save a .mat file and 4 images into your directory.
        i.	Input_batch.mat, where “batch” is set by the user for recall purposes
        ii.	Batch_im_rat_bg.jpg = top image with background
        iii.	Batch_im_rat.jpg = top image without background
        iv.	Batch_im_paw_bg.jpg = bottom image with background
        v.	Batch_im_paw.jpg = bottom image without background
3.	Type “colorThresholder” into the command line to open this app.
    a.	The four images provided by InputSetup can be used to determine the optimal filter setup for your batch. Filters can be created using RGB, HSV, LAB, or YCbCr thresholds. 
    b.	Two filters must be created to properly run AGATHA.
        i.	The “rat” filter can be determined using the im_rat images. The “paw” filter can be determined using the im_paw images.
        ii.	The _bg image allows a filter to be created without first subtracting the image background. The rat/paw only image allows filtering based off of an image with the background removed from the frame. Either of these images can create a viable filter sample; your preference will be dependent on your lighting conditions and the contrast/color saturation of your videos. 
        iii.	Any combination of a rat and paw filter can be used. HOWEVER, do NOT create two rat filters (using both the with and without background images) or two paw filters.
    c.	When optimizing the filters, check the binary image before outputting the function. Ideally, the binary image will appear to show a white rat silhouette on a pure black background or white paw prints on a pure black background.
    d.	Select “Export” from the app’s menu and the “Export Function” option.
    e.	Save the function with a unique name in your current directory.
    i.	BE SURE you create TWO functions (one for rat and one for paw) with readily distinguishable names.
        ii.	Also, be sure to remember if you used background images or not.
4.	If you need a filter that runs your videos through multiple color spaces (ie, run an RGB filter and then pass that filtered image through an HSV filter) use the following instructions:
    Note: this method may require additional troubleshooting.
    a.	Create your first color space filter as described in step 3.
    b.	Export BOTH the image and the function.
    c.	Save function as normal and reopen colorThresholder with the newly saved, filtered image loaded.
    d.	Create the needed secondary color space filter and export the function.
    e.	Copy and paste the new filter function code (without the function call line) inside of your primary filter function. Re-save the primary filter with your changes.
    f.	Continue with the following steps as normal.
5.	Check that your Input_batch.mat and both of your filters are in the correct directory before proceeding.
6.	Before running a full batch in AGATHA, run the video used to create the filter images (using the steps below). Check the FSTO and pawprint outputs to ensure the filter is running as desired (ie no banding in the raw FSTO images).
7.	Call the AGATHA function in the command line:  AGATHAv2 (Input,RatFilter,PawFilter,BGcase)  
    a.	Input = the name of your ‘Input_batch.mat’
    b.	RatFilter = the name of your rat filter function also contained in ‘’
    c.	PawFilter = the name of your paw filter function also contained in ‘’
    d.	BGCase = ‘rat’, ‘paw’, ‘both’, or ‘none’
        i.	‘rat’ will apply background subtraction to the rat filter only
        ii.	‘paw’ will apply background subtraction to the paw filter only
        iii.	‘both’ will apply background subtraction to both the rat and paw filters
        iv.	‘none’ will not apply background subtraction for either filter
        v.	Background subtraction can be determined based on which image used to create your filters. (i.e., if paw filter is created using ‘im_bottom_bg’, the paw filter was created WITHOUT subtracting the background and either the ‘rat’ or ‘none’ setting should be used).
    e.	Editor = ‘Run’ or ‘Edit’.  Run will execute the code as normal.  Edit will allow you to edit the FSTO for each trial.
8.	AGATHA will prompt directory selection (if your videos are located across several folders, etc, simply select the drive they are all located on). Navigate to your desired directory and hit “ok”.
9.	AGATHA will allow you to select files to compose your batch. Any number of files can be selected; a single file can also be run. The selection GUI provides recall and remove functionality to assist in batch creation. Be sure to click the “add” button once your video selection(s) are made.
10.	AGATHA will output a DATA.mat file for each video (saved with the trial name as the prefix) as well as FSTO and pawprint images for checking. 
11.	Your FSTO images will likely need edited.  To do this, rerun AGATHA and make a batch of only the video trials you need to edit.  Also, change the ‘Run’ in the function call to ‘Edit’.  Then, follow the GUI instructions for editing your FSTO image.  In the end, you will have an edited image and a new DATA.mat file to match. 
    a.	For examples on what FSTO images to look like, read the FSTO Help document. 
12.	Call AGATHACalculator with your batch name. 
    a.	Example: AGATHACalculator(‘Exp_Wk2’)
    b.	Create a batch as you did in AGATHA – but this time select all the DATA.mat files from your trials. 
    c.	The calculator code will output an excel sheet for each trial and also continuously append to a master spreadsheet of data with medians for all trials. 

