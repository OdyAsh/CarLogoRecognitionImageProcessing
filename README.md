# About

MatLab code that takes car images as input, and outputs cropped images of the cars' logos with their names using image processing techniques.
<br>
More details are found [here](https://github.com/OdyAsh/CarLogoRecognitionImageProcessing/blob/main/Ashraf196280%20-%20Vehicle%20Logo%20Recognition.docx)
## Logos database 
pics which the cropped images are compared with (to determine the logo's name)

<img
  src="https://github.com/OdyAsh/CarLogoRecognitionImageProcessing/blob/main/ReadmePics/0.logosDB.png"
  style="display: inline-block; margin: 0 auto; max-width: 400px">

## Example 1

### Input and processing details
<img
  src="https://github.com/OdyAsh/CarLogoRecognitionImageProcessing/blob/main/ReadmePics/1.chevInput.png"
  style="display: inline-block; margin: 0 auto; max-width: 400px">

### Visualization of cropping mechanism near the resulted mask
Note that the output is at the last cell in the grid

<img
  src="https://github.com/OdyAsh/CarLogoRecognitionImageProcessing/blob/main/ReadmePics/2.chevLoops.png"
  style="display: inline-block; margin: 0 auto; max-width: 400px">

## Example 2
### All test case inputs
<img
  src="https://github.com/OdyAsh/CarLogoRecognitionImageProcessing/blob/main/ReadmePics/3.inputs.png"
  style="display: inline-block; margin: 0 auto; max-width: 400px">
### Outputs
<img
  src="https://github.com/OdyAsh/CarLogoRecognitionImageProcessing/blob/main/ReadmePics/4.outputs.png"
  style="display: inline-block; margin: 0 auto; max-width: 400px">

# Disadvantages
As you can see, the logos database are taken from the test case images to work, that's because the feature comparison used (fft2) is inefficient.

## Contributing
Any forks/pull requests are welcome!

## License
[MIT](https://choosealicense.com/licenses/mit/)
