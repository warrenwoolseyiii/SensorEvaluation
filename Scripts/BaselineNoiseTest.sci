/************************************************/
/*              Sensor information              */
/************************************************/
ak09904 = struct('name', "AK09904", 'xSF', 0.01, 'ySF', 0.01, 'zSF', 0.01, 'xRange', 1310, 'yRange', 1310, 'zRange', 1310);
mmc = struct('name', "MEMSIC", 'xSF', 0.00625, 'ySF', 0.00625, 'zSF', 0.00625, 'xRange', 1600, 'yRange', 1600, 'zRange', 1600);
drv = struct('name', "DRV425", 'xSF', 0.0915, 'ySF', 0.0915, 'zSF', 0.0915, 'xRange', 4000, 'yRange', 4000, 'zRange', 4000);
bmx160 = struct('name', "BMX160", 'xSF', 0.344, 'ySF', 0.344, 'zSF', 0.769, 'xRange', 2300, 'yRange', 2300, 'zRange', 5000);
bmx055 = struct('name', "BMX055", 'xSF', 0.333, 'ySF', 0.333, 'zSF', 0.143, 'xRange', 2600, 'yRange', 2600, 'zRange', 5000);
fxos = struct('name', "FXOS8700", 'xSF', 0.1, 'ySF', 0.1, 'zSF', 0.1, 'xRange', 2400, 'yRange', 2400, 'zRange', 2400);
mmc5883 = struct('name', "MMC5883", 'xSF', 0.025, 'ySF', 0.025, 'zSF', 0.025, 'xRange', 1600, 'yRange', 1600, 'zRange', 1600);

sensor = mmc5883;

/************************************************/
/*     Determine the frequency of the samples   */
/************************************************/
// Time stamp map struct containing empty vectors
TSMap = struct('value', '0', 'count', '0');
vals = [];
count = [];
TSMap.value = vals;
TSMap.count = count;

// Empty vector for calculating deltas
deltaTMS = [];

// Average delta value
avgDelta = 0;
totalSampleCnt = 0;

// Calculate the time stamp deltas - also scale the input
for i=2:length(dataSet(:,1))
    deltaTMS(i-1) = dataSet(i,1) - dataSet(i-1,1);
end

// Populate the map with the various delta values
for i=1:100
    TSMap.value(i) = i;
    TSMap.count(i) = sum(deltaTMS==i);
    avgDelta = avgDelta + (TSMap.value(i) *  TSMap.count(i));
    totalSampleCnt = totalSampleCnt + TSMap.count(i);
end

// Claculate the average delta, and average frequency
sampleFreqReport = struct('avgDeltaT', '0', 'sampleFreq', '0');
avgDelta = ( avgDelta / totalSampleCnt ) * 0.001;
avgFreq = 1 / avgDelta;
sampleFreqReport.avgDeltaT = avgDelta;
sampleFreqReport.sampleFreq = avgFreq;

/************************************************/
/*          Get the PSD of the signal           */
/************************************************/
// Capture 1 full second of data
samplesPerSec = uint32(avgFreq);
if length(dataSet(:,1)) < samplesPerSec then
    print("not enough samples for 1 second of data!");
end

// Create the time series and make a single vector from the x, y, and z components
timeSeries = [];
time = [];
for i=1:samplesPerSec
    x = dataSet(i,3) * sensor.xSF;
    y = dataSet(i,4) * sensor.ySF;
    z = dataSet(i,5) * sensor.zSF;
    timeSeries(i) = sqrt(x*x + y*y + z*z);
    time(i) = i * avgDelta;
end

// Remove the DC component
avg = mean(timeSeries);
timeSeries = timeSeries - avg;

// Transform the time series into frequency domain
freqSeries = fft(timeSeries);
freqMag = abs(freqSeries);


/************************************************/
/*          Get the noise band on each axis     */
/************************************************/
// Find the largest and smallest value from the normalized signal
noiseRange = struct('xCounts' , '0', 'yCounts' , '0', 'zCounts' , '0', 'x', '0', 'y', '0', 'z', '0');
maxX = max(dataSet(:,3));
maxY = max(dataSet(:,4));
maxZ = max(dataSet(:,5));
minX = min(dataSet(:,3));
minY = min(dataSet(:,4));
minZ = min(dataSet(:,5));
noiseRange.xCounts = abs(maxX - minX);
noiseRange.yCounts = abs(maxY - minY);
noiseRange.zCounts = abs(maxZ - minZ);
noiseRange.x = noiseRange.xCounts * sensor.xSF;
noiseRange.y = noiseRange.yCounts * sensor.ySF;
noiseRange.z = noiseRange.zCounts * sensor.zSF;

/************************************************/
/*          Generate the report and plots       */
/************************************************/
// Print information to the console
printf("***** %s Baseline Noise Test *****\n", sensor.name);
printf("\tTest parameters:\n\t\tSampling Frequency = %f\n\t\tRange X, Y, Z = %d uT, %d uT, %d uT\n", sampleFreqReport.sampleFreq, sensor.xRange, sensor.yRange, sensor.zRange);
printf("\tNoise range:\n\t\tCounts X, Y, Z = %d cnts, %d cnts, %d cnts\n\t\tScaled X, Y, Z = %f uT, %f uT, %f uT\n", noiseRange.xCounts, noiseRange.yCounts, noiseRange.zCounts, noiseRange.x, noiseRange.y, noiseRange.z);

// Clear plots
xdel(winsid());

// Plot 1 second worth of raw signal in counts
scf(1);
clf(1);
plot(dataSet(1:samplesPerSec,1), (dataSet(1:samplesPerSec,3) * sensor.xSF), 'b');
plot(dataSet(1:samplesPerSec,1), (dataSet(1:samplesPerSec,4) * sensor.ySF), 'r');
plot(dataSet(1:samplesPerSec,1), (dataSet(1:samplesPerSec,5) * sensor.zSF), 'g');

// Band the x noise
xBand = mean(dataSet(1:samplesPerSec,3)) * sensor.xSF;
xBandH = [];
xBandL = [];
for i=1:samplesPerSec
    xBandH(i) = xBand + (noiseRange.x / 2);
    xBandL(i) = xBand - (noiseRange.x / 2);
end

plot(dataSet(1:samplesPerSec,1), xBandH);
plot(dataSet(1:samplesPerSec,1), xBandL);


// Band the y noise
yBand = mean(dataSet(1:samplesPerSec,4)) * sensor.ySF;
yBandH = [];
yBandL = [];
for i=1:samplesPerSec
    yBandH(i) = yBand + (noiseRange.y / 2);
    yBandL(i) = yBand - (noiseRange.y / 2);
end

plot(dataSet(1:samplesPerSec,1), yBandH);
plot(dataSet(1:samplesPerSec,1), yBandL);

// Band the z noise
zBand = mean(dataSet(1:samplesPerSec,5)) * sensor.zSF;
zBandH = [];
zBandL = [];
for i=1:samplesPerSec
    zBandH(i) = zBand + (noiseRange.z / 2);
    zBandL(i) = zBand - (noiseRange.z / 2);
end

plot(dataSet(1:samplesPerSec,1), zBandH);
plot(dataSet(1:samplesPerSec,1), zBandL);

xlabel("Time (ms)");
ylabel("Magnetic Field Strength (uT)");
title("Noise banding");

// Plot the PSD in the frequency domain
scf(2);
clf(2);
plot(freqMag(1:samplesPerSec/2))
xlabel("Frequency (Hz)");
ylabel("Power (db)");
title("PSD of sensor noise");








