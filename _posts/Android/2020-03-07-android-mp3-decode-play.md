---
title: 02:Android多媒体-MP3边解码边播放
author: Zhusong
layout: post
footer: true
category: Android
date: 2020-3-07
excerpt: "02:Android多媒体-MP3边解码边播放"
abstract: ""
---

# 功能需求
在直播场景下, 需要添加音乐作为伴奏, 这里的功能点就涉及到解码/播放/重采样/混音几个功能点, 这里我先去除直播场景, 只实现解码与播放。

# 思路
最简单的播放就是使用MediaPlayer实现播放, 如果只有一个播放需求可以直接使用这个类即可, 不需要再看了。  

我们的场景是需要拿到PCM音频裸数据, 要添加到直播流中, 所以我们这里需要先解码出PCM数据, 当然在播放时还是使用MediaPlayer, 但是这样有点多余, 因为MediaPlayer底层也是解码后播放, 相当于一件事件, 同时做了2遍, 对系统资源是种消耗, 直播本身对编解码是个比较重的工作, 还是尽量减少没有必要的编解码工作。  

这里我们用到AudioTrack来实现播放功能, 使用解码出的音频数据进行播放。 
 
解码是个比较耗时的任务, 我们会开启一个线程(__MP3DecodeThread__)单独执行。为了扩展性, 我们在定义一个接口(__IMP3DecodeCallback__)执行 *开始/返回数据/结束* 状态的回调, 定义一个类来播放MP3(__MP3Player__), 这个类通过实现 __IMP3DecodeCallback__ 接口, 来播放PCM数据, 当然根据场景需要可以去重写 __MP3Player__ 满足自己的需求。


> 需要用到的几个系统类:  
> AudioTrack: PCM播放器   
> MediaCodec: MP3解码器   
> MediaExtractor: MP3多媒体提取器   

# 实现
* 继承Thread实现MP3DecodeThread, 传入构造文件路径, 支持assets以及文件路径

	```java
	public class MP3DecodeThread extends Thread {
	
		private String mPath;
		private AssetFileDescriptor mAFD;
		    
		public MP3DecodeThread(String path) {
		    super("DecodeThread");
		    this.mPath = path;
		}
		
		public MP3DecodeThread(AssetFileDescriptor afd) {
		    super("DecodeThread");
		    this.mAFD = afd;
		}	
	}
	```

* 在run方法中执行解码过程, 分几步走
	* MediaExtractor提取MP3获得MeidaFormat
	* 开启解码器MeidaCodec线程
	* 循环提取MediaExtractor的编码的音频数据, 并压入解码器中, 获取解码器解码好的PCM裸数据
	* 提取器没有数据, 添加结束标记到解码器
	* 解码器识别到结束标记结束解码
	* 释放MediaExtractor & MeidaCodec

	```java
	@Override
    public void run() {

        if (TextUtils.isEmpty(mPath) && null == mAFD) {
            setDone();
            return;
        }

        MediaLog.d("Run extractor MP3");
        // 1. 解码文件格式
        MediaExtractor extractor = new MediaExtractor();
        try {
            if (!TextUtils.isEmpty(mPath)) {
                extractor.setDataSource(mPath);
            } else if (null != mAFD) {
                extractor.setDataSource(mAFD.getFileDescriptor(), mAFD.getStartOffset(), mAFD.getLength());
            }
        } catch (Exception e) {
            MediaLog.e(e);
            extractor.release();
            extractor = null;
        }
        if (null == extractor) {
            MediaLog.e("extractor is null");
            setDone();
            return;
        }
        MediaFormat audioFormat = null;
        for (int i = 0; i < extractor.getTrackCount(); i++) {
            MediaFormat format = extractor.getTrackFormat(i);
            String mime = format.getString(MediaFormat.KEY_MIME);
            if (!TextUtils.isEmpty(mime) && mime.startsWith("audio/")) {
                extractor.selectTrack(i);
                audioFormat = format;
                break;
            }
        }

        if (null == audioFormat) {
            MediaLog.e("audioFormat is null");
            setDone();
            return;
        }
        String mime = audioFormat.getString(MediaFormat.KEY_MIME);
        if (TextUtils.isEmpty(mime)) {
            MediaLog.e("mime is null");
            setDone();
            return;
        }

        // 2. 开启解码器
        MediaCodec decoder = null;
        try {
            decoder = MediaCodec.createDecoderByType(mime);
            decoder.configure(audioFormat, null, null, 0);
            decoder.start();
        } catch (Exception e) {
            MediaLog.e(e);
            if (null != decoder) {
                decoder.release();
                decoder = null;
            }
        }
        if (null == decoder) {
            MediaLog.e("decoder is null");
            setDone();
            return;
        }

        if (null != mCallback) {
            try {
                mCallback.onFormat(audioFormat);
            } catch (Exception e) {
                MediaLog.e(e);
            }
        }

        // 3. 解码PCM
        boolean endOfStream = false;
        int err = 0;
        while (!endOfStream && !isInterrupted()) {
            // 读取一次样本 写入 解码器
            try {
                int bufferIndex = decoder.dequeueInputBuffer(10);
                if (bufferIndex >= 0) {
                    ByteBuffer[] inputBuffers = decoder.getInputBuffers();
                    ByteBuffer bufferCache = inputBuffers[bufferIndex];
                    bufferCache.clear();
                    int audioSize = extractor.readSampleData(bufferCache, 0);

                    // 得到buffer之后, dequeueInputBuffer与queueInputBuffer必须一对一调用
                    // 否则解码器输入buffer会不够
                    if (audioSize < 0) {
                    // 4. 没有可用数据, 标记结束
                        endOfStream = true;
                        MediaLog.w("readSampleData : error audioSize = " + audioSize);
                        decoder.queueInputBuffer(bufferIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
                    } else {
                        decoder.queueInputBuffer(bufferIndex, 0, audioSize, extractor.getSampleTime(), 0);
                        extractor.advance();
                    }
                }
            } catch (Exception e) {
                MediaLog.e(e);
            }

            // 读取器解码器数据
            while (!isInterrupted()) {
                MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
                int bufferIndex = decoder.dequeueOutputBuffer(info, 10);
                ByteBuffer[] buffers = decoder.getOutputBuffers();
                if (bufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    MediaFormat format = decoder.getOutputFormat();
                } else if (bufferIndex == MediaCodec.INFO_OUTPUT_BUFFERS_CHANGED) {
                    buffers = decoder.getOutputBuffers();
                } else if (bufferIndex == MediaCodec.INFO_TRY_AGAIN_LATER) {
                    // no available data, break
                    if (!endOfStream) {
                        break;
                    } else {
                        // wait to end
                        MediaLog.d("drainEncoder : wait for eos");
                        try {
                            Thread.sleep(10);
                        } catch (InterruptedException e) {
                            e.printStackTrace();
                        }
                    }
                } else if (bufferIndex < 0) {
                    MediaLog.w("drainEncoder : bufferIndex < 0 ");
                } else {
                    boolean isReachEnd = (info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0;

                    ByteBuffer data = buffers[bufferIndex]; // data after decode(PCM)

                    // 注意这个buffer要及时使用归还, 不然解码器的可用buffer会不够
                    if (null != mCallback) {
                        try {
                            mCallback.onDrain(data, info.presentationTimeUs);
                        } catch (Exception e) {
                            MediaLog.e(e);
                        }
                    }
                    // 每次都要释放, 与dequeueOutputBuffer必须一对一调用, 不然解码器的可用buffer会不够
                    decoder.releaseOutputBuffer(bufferIndex, false);
					// 5. 识别结束标记, 退出循环
                    if (isReachEnd) {
                        if (!endOfStream) {
                            err = ERR_UNEXPECTED_END;
                            MediaLog.w("Audio drainEncoder : reached end of stream unexpectedly");
                        } else {
                            MediaLog.d("Audio drainEncoder : end of stream reached");
                        }
                        break;
                    }
                }
            }
        }

        // 6. 释放相关资源
        // 释放MediaCodec
        try {
            decoder.stop();
            decoder.release();
        } catch (Exception e) {
            MediaLog.e(e);
        }
        // 释放MediaExtractor
        try {
            extractor.release();
        } catch (Exception e) {
            MediaLog.e(e);
        }

        err = err >= 0 && isInterrupted() ? ERR_INTERRUPT : err;
        if (null != mCallback) {
            try {
                mCallback.onEndOfStream(err);
            } catch (Exception e) {
                MediaLog.e(e);
            }
        }
        setDone();
    }
	```
	
* 创建MP3解码回调接口, 解耦合编码过程

	```java
	public interface IMP3DecodeCallback {

	    void onFormat(MediaFormat format);
	
	    void onDrain(ByteBuffer buffer, long presentationTimeUs);
	
	    void onEndOfStream(int err);
	}
	```
	
* 创建播放器, 在合适的时机做创建/播放/释放。
	* 在onFormat回调中创建AudioTrack, 并且开始播放, AudioTrack需要的参数都在MediaFormat当中
	* 在onDrain回调中塞入解码好的音频数据, 在其他场景就可以重写该方法
	* 在onEndOfStream结束时, 释放AudioTrack

	```java
	public class MP3Player implements IMP3DecodeCallback{

	    //===========播放相关============//
	    // 播放器
	    private AudioTrack mAudioTrack = null;
	   
	    @Override
	    public void onFormat(MediaFormat format) {
	        if (null == format) {
	            return;
	        }
	
	        int sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE);
	        int channelCount = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT);
	        int audioFormat = channelCount > 1 ? AudioFormat.CHANNEL_OUT_STEREO : AudioFormat.CHANNEL_OUT_MONO;

	        // 获取最小buffer大小
	        int bufferSize = AudioTrack.getMinBufferSize(sampleRate,
	                audioFormat, AudioFormat.ENCODING_PCM_16BIT);
	        mAudioTrack = new AudioTrack(AudioManager.STREAM_MUSIC, sampleRate, audioFormat,
	                AudioFormat.ENCODING_PCM_16BIT, bufferSize, AudioTrack.MODE_STREAM);
	        mAudioTrack.play();
	    }
	
	    @Override
	    public void onDrain(ByteBuffer buffer, long presentationTimeUs) {
	        if (null == mAudioTrack) {
	            return;
	        }
	        if (null == buffer || buffer.remaining() <= 0) {
	            return;
	        }
	        byte[] data = new byte[buffer.remaining()];
	        buffer.get(data);
	        mAudioTrack.write(data, 0, data.length);
	    }
	
	    @Override
	    public void onEndOfStream(int err) {
	        if (null != mAudioTrack) {
	            try {
	                mAudioTrack.stop();
	                mAudioTrack.release();
	                mAudioTrack = null;
	            } catch (Exception e) {
	                MediaLog.e("onEndOfStream : " + err, e);
	            }
	        }
	    }
    }
	```
	
* 使用方法

	```java
	// 创建播放器
	MP3Player player = new MP3Player();
	// 开始解码
	MP3DecodeThread  thread = new MP3DecodeThread({afd/path});
	thread.setCallback(player);
	thread.start();
	```

# Android Stuido引入

implementation 'cn.com.lasong:media:0.0.1'

# 开源库地址
<https://github.com/zhusonger/androidz_media>