#import "OpenCVTestViewController.h"

#import <opencv2/imgproc/imgproc_c.h>
#import <opencv2/objdetect/objdetect.hpp>

@implementation OpenCVTestViewController
@synthesize imageView;

- (void)dealloc {
	AudioServicesDisposeSystemSoundID(alertSoundID);
	[imageView dealloc];
	[super dealloc];
}

#pragma mark -
#pragma mark OpenCV Support Methods

// NOTE you SHOULD cvReleaseImage() for the return value when end of the code.
- (IplImage *)CreateIplImageFromUIImage:(UIImage *)image {
	CGImageRef imageRef = image.CGImage;

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	IplImage *iplimage = cvCreateImage(cvSize(image.size.width, image.size.height), IPL_DEPTH_8U, 4);
	CGContextRef contextRef = CGBitmapContextCreate(iplimage->imageData, iplimage->width, iplimage->height,
													iplimage->depth, iplimage->widthStep,
													colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
	CGContextDrawImage(contextRef, CGRectMake(0, 0, image.size.width, image.size.height), imageRef);
	CGContextRelease(contextRef);
	CGColorSpaceRelease(colorSpace);

	IplImage *ret = cvCreateImage(cvGetSize(iplimage), IPL_DEPTH_8U, 3);
	cvCvtColor(iplimage, ret, CV_RGBA2BGR);
	cvReleaseImage(&iplimage);

	return ret;
}

// NOTE You should convert color mode as RGB before passing to this function
- (UIImage *)UIImageFromIplImage:(IplImage *)image {
	NSLog(@"IplImage (%d, %d) %d bits by %d channels, %d bytes/row %s", image->width, image->height, image->depth, image->nChannels, image->widthStep, image->channelSeq);

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	NSData *data = [NSData dataWithBytes:image->imageData length:image->imageSize];
	CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
	CGImageRef imageRef = CGImageCreate(image->width, image->height,
										image->depth, image->depth * image->nChannels, image->widthStep,
										colorSpace, kCGImageAlphaNone|kCGBitmapByteOrderDefault,
										provider, NULL, false, kCGRenderingIntentDefault);
	UIImage *ret = [UIImage imageWithCGImage:imageRef];
	CGImageRelease(imageRef);
	CGDataProviderRelease(provider);
	CGColorSpaceRelease(colorSpace);
	return ret;
}

#pragma mark -
#pragma mark Utilities for intarnal use

- (void)showProgressIndicator:(NSString *)text {
	self.view.userInteractionEnabled = FALSE;
	if(!progressHUD) {
		CGFloat w = 160.0f, h = 120.0f;
		progressHUD = [[UIProgressHUD alloc] initWithFrame:CGRectMake((self.view.frame.size.width-w)/2, (self.view.frame.size.height-h)/2, w, h)];
		[progressHUD setText:text];
		[progressHUD showInView:self.view];
	}
}

- (void)hideProgressIndicator {
	self.view.userInteractionEnabled = TRUE;
	if(progressHUD) {
		[progressHUD hide];
		[progressHUD release];
		progressHUD = nil;

		AudioServicesPlaySystemSound(alertSoundID);
	}
}

- (void)opencvBeautify: (UIGestureRecognizer *) sender{
    if (sender.numberOfTouches == 1 && currentActionItem == CVActionItemBeautify) {
        CGPoint point = [sender locationOfTouch:0 inView:imageView];
        IplImage *src_img = [self CreateIplImageFromUIImage:imageView.image];
		IplImage *mask_img = cvCreateImage(cvGetSize(src_img), IPL_DEPTH_8U, 1);
        IplImage *dst_img = cvCloneImage (src_img);
        
        cvZero(mask_img);
        cvCircle( mask_img, cvPoint(point.x*2,point.y*2-50), 
                 10, CV_RGB(255,255,255), -1, 8, 0 );
        
        cvInpaint (src_img, mask_img, dst_img, 10.0, CV_INPAINT_NS);
        
        cvCvtColor(dst_img, src_img, CV_BGR2RGB);
        imageView.image = [self UIImageFromIplImage:src_img];
        
        cvReleaseImage(&src_img);
        cvReleaseImage(&mask_img);
        cvReleaseImage(&dst_img);
        
    }
   
}

- (void)opencvFlipImage {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
	if(imageView.image) {
		cvSetErrMode(CV_ErrModeParent);
        
        int angle = 45;
        float m[6];
		IplImage *src_img = [self CreateIplImageFromUIImage:imageView.image];
		IplImage *dst_img = cvCloneImage (src_img);
        CvMat M;
		
        m[0] = (float) (cos (angle * CV_PI / 180.0));
        m[1] = (float) (-sin (angle * CV_PI / 180.0));
        m[2] = src_img->width * 0.5;
        m[3] = -m[1];
        m[4] = m[0];
        m[5] = src_img->height * 0.5;
        cvInitMatHeader (&M, 2, 3, CV_32FC1, m, CV_AUTOSTEP);
        
        cvGetQuadrangleSubPix (src_img, dst_img, &M);
        
        cvCvtColor(dst_img, src_img, CV_BGR2RGB);
		imageView.image = [self UIImageFromIplImage:src_img];
        cvReleaseImage(&src_img);
		cvReleaseImage(&dst_img);
        
	}
    [self hideProgressIndicator];
    
	[pool release];
}

- (void) opencvIncise {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    if (imageView.image) {
        cvSetErrMode(CV_ErrModeParent);
        IplImage *org = [self CreateIplImageFromUIImage:imageView.image];
        IplImage *image = cvCloneImage(org);
        int width = image->width;
        int height = image->height;
        int step = image->widthStep;
        int channel = image->nChannels;
        uchar* data = (uchar *)image->imageData;
        for(int i=0; i<width-1; i++) {
            for(int j=0; j<height-1; j++) {
                for(int k=0; k<channel; k++) {
                    int temp = data[(j+1)*step+(i+1)*channel+k]-data[j*step+i*channel+k]+128;//浮雕
                    if(temp > 255) {
                        data[j*step+i*channel+k] = 255;
                    } else if(temp < 0) {
                        data[j*step+i*channel+k] = 0;
                    } else {
                        data[j*step+i*channel+k] = temp;
                    }
                }
            }
        }

        imageView.image = [self UIImageFromIplImage:image];
        cvReleaseImage(&org);
        cvReleaseImage(&image);
    }
    [self hideProgressIndicator];
    [pool release];
}

#pragma mark -
#pragma mark IBAction

- (IBAction)loadImage:(id)sender {
	if(!actionSheetAction) {
		UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@""
																 delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil
														otherButtonTitles:@"Use Photo from Library", @"Take Photo with Camera", @"Use Default Image", nil];
		actionSheet.actionSheetStyle = UIActionSheetStyleDefault;
		actionSheetAction = ActionSheetToSelectTypeOfSource;
		[actionSheet showInView:self.view];
		[actionSheet release];
	}
}

- (IBAction)saveImage:(id)sender {
	if(imageView.image) {
		[self showProgressIndicator:@"Saving"];
		UIImageWriteToSavedPhotosAlbum(imageView.image, self, @selector(finishUIImageWriteToSavedPhotosAlbum:didFinishSavingWithError:contextInfo:), nil);
	}
}

- (void)finishUIImageWriteToSavedPhotosAlbum:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
	[self hideProgressIndicator];
}

- (IBAction)beautifyEffect:(id)sender {
    currentActionItem = CVActionItemBeautify;
}

- (IBAction)InciseEffect:(id)sender {
    currentActionItem = CVActionItemIncise;
    [self showProgressIndicator:@"Waiting"];
    [self performSelectorInBackground:@selector(opencvIncise) withObject:nil];
    
}

- (IBAction)flipEffect:(id)sender {
    currentActionItem = CVActionItemFlip;
    [self showProgressIndicator:@"Waiting"];
    [self performSelectorInBackground:@selector(opencvFlipImage) withObject:nil];
}

#pragma mark -
#pragma mark UIViewControllerDelegate

- (void)viewDidLoad {
	[super viewDidLoad];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	[self loadImage:nil];

	NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"Tink" ofType:@"aiff"] isDirectory:NO];
	AudioServicesCreateSystemSoundID((CFURLRef)url, &alertSoundID);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return NO;
}

#pragma mark -
#pragma mark UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	switch(actionSheetAction) {
		case ActionSheetToSelectTypeOfSource: {
			UIImagePickerControllerSourceType sourceType;
			if (buttonIndex == 0) {
				sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
			} else if(buttonIndex == 1) {
				sourceType = UIImagePickerControllerSourceTypeCamera;
			} else if(buttonIndex == 2) {
				NSString *path = [[NSBundle mainBundle] pathForResource:@"lena" ofType:@"jpg"];
				imageView.image = [UIImage imageWithContentsOfFile:path];
                
                UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(opencvBeautify:)];
                gesture.numberOfTapsRequired = 1;
                [imageView addGestureRecognizer:gesture];
                [gesture release];
                imageView.userInteractionEnabled = YES;

				break;
			} else {
				// Cancel
				break;
			}
			if([UIImagePickerController isSourceTypeAvailable:sourceType]) {
				UIImagePickerController *picker = [[UIImagePickerController alloc] init];
				picker.sourceType = sourceType;
				picker.delegate = self;
				picker.allowsImageEditing = NO;
				[self presentModalViewController:picker animated:YES];
				[picker release];
			}
			break;
		}
		case ActionSheetToSelectTypeOfMarks: {
			if(buttonIndex != 0 && buttonIndex != 1) {
				break;
			}

			UIImage *image = nil;
			if(buttonIndex == 1) {
				NSString *path = [[NSBundle mainBundle] pathForResource:@"laughing_man" ofType:@"png"];
				image = [UIImage imageWithContentsOfFile:path];
			}

			[self showProgressIndicator:@"Detecting"];
			[self performSelectorInBackground:@selector(opencvFaceDetect:) withObject:image];
			break;
		}
	}
	actionSheetAction = 0;
}

#pragma mark -
#pragma mark UIImagePickerControllerDelegate

- (UIImage *)scaleAndRotateImage:(UIImage *)image {
	static int kMaxResolution = 640;
	
	CGImageRef imgRef = image.CGImage;
	CGFloat width = CGImageGetWidth(imgRef);
	CGFloat height = CGImageGetHeight(imgRef);
	
	CGAffineTransform transform = CGAffineTransformIdentity;
	CGRect bounds = CGRectMake(0, 0, width, height);
	if (width > kMaxResolution || height > kMaxResolution) {
		CGFloat ratio = width/height;
		if (ratio > 1) {
			bounds.size.width = kMaxResolution;
			bounds.size.height = bounds.size.width / ratio;
		} else {
			bounds.size.height = kMaxResolution;
			bounds.size.width = bounds.size.height * ratio;
		}
	}
	
	CGFloat scaleRatio = bounds.size.width / width;
	CGSize imageSize = CGSizeMake(CGImageGetWidth(imgRef), CGImageGetHeight(imgRef));
	CGFloat boundHeight;
	
	UIImageOrientation orient = image.imageOrientation;
	switch(orient) {
		case UIImageOrientationUp:
			transform = CGAffineTransformIdentity;
			break;
		case UIImageOrientationUpMirrored:
			transform = CGAffineTransformMakeTranslation(imageSize.width, 0.0);
			transform = CGAffineTransformScale(transform, -1.0, 1.0);
			break;
		case UIImageOrientationDown:
			transform = CGAffineTransformMakeTranslation(imageSize.width, imageSize.height);
			transform = CGAffineTransformRotate(transform, M_PI);
			break;
		case UIImageOrientationDownMirrored:
			transform = CGAffineTransformMakeTranslation(0.0, imageSize.height);
			transform = CGAffineTransformScale(transform, 1.0, -1.0);
			break;
		case UIImageOrientationLeftMirrored:
			boundHeight = bounds.size.height;
			bounds.size.height = bounds.size.width;
			bounds.size.width = boundHeight;
			transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width);
			transform = CGAffineTransformScale(transform, -1.0, 1.0);
			transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
			break;
		case UIImageOrientationLeft:
			boundHeight = bounds.size.height;
			bounds.size.height = bounds.size.width;
			bounds.size.width = boundHeight;
			transform = CGAffineTransformMakeTranslation(0.0, imageSize.width);
			transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
			break;
		case UIImageOrientationRightMirrored:
			boundHeight = bounds.size.height;
			bounds.size.height = bounds.size.width;
			bounds.size.width = boundHeight;
			transform = CGAffineTransformMakeScale(-1.0, 1.0);
			transform = CGAffineTransformRotate(transform, M_PI / 2.0);
			break;
		case UIImageOrientationRight:
			boundHeight = bounds.size.height;
			bounds.size.height = bounds.size.width;
			bounds.size.width = boundHeight;
			transform = CGAffineTransformMakeTranslation(imageSize.height, 0.0);
			transform = CGAffineTransformRotate(transform, M_PI / 2.0);
			break;
		default:
			[NSException raise:NSInternalInconsistencyException format:@"Invalid image orientation"];
	}
	
	UIGraphicsBeginImageContext(bounds.size);
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (orient == UIImageOrientationRight || orient == UIImageOrientationLeft) {
		CGContextScaleCTM(context, -scaleRatio, scaleRatio);
		CGContextTranslateCTM(context, -height, 0);
	} else {
		CGContextScaleCTM(context, scaleRatio, -scaleRatio);
		CGContextTranslateCTM(context, 0, -height);
	}
	CGContextConcatCTM(context, transform);
	CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, width, height), imgRef);
	UIImage *imageCopy = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	return imageCopy;
}

- (void)imagePickerController:(UIImagePickerController *)picker
		didFinishPickingImage:(UIImage *)image
				  editingInfo:(NSDictionary *)editingInfo
{
	imageView.image = [self scaleAndRotateImage:image];
	[[picker parentViewController] dismissModalViewControllerAnimated:YES];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[[picker parentViewController] dismissModalViewControllerAnimated:YES];
}
@end