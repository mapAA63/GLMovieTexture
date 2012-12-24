#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import "GLMovieTexture.h"

#define EMBEDED_MOVIE_CHUNK_ID "emMv"

static NSString* GetMoviePath(const char *name);

#define DUMP(...) { fprintf(stderr,__VA_ARGS__); fputc('\n',stderr); }
#define GetInstance(iid) ((GLMovieTexture*)(uintptr_t)(iid))

uint64_t _Load(const char *name,uint32_t textureId){
	NSString *path = GetMoviePath(name);
	if( !path ){
		DUMP("Failed to find movie '%s'",name);
		return 0;
	}
	GLMovieTexture *instance = [[GLMovieTexture alloc] init];
	[instance setGLContext:[EAGLContext currentContext]];
	[instance setMovie:path];
	[instance setTargetTextureId:textureId];
	[instance setCurrentTime:3.0];
	DUMP("Load(%s,%d)",name,textureId);
	return (uint64_t)(uintptr_t)instance;
}

void _Unload(uint64_t instanceId){
	DUMP("Unload(%llx)",instanceId);
	if( instanceId==0 ){ return; }
	GLMovieTexture *instance = GetInstance(instanceId);
	[instance release];
}

void _Play(uint64_t instanceId){
	DUMP("Play(%llx)",instanceId);
	if( instanceId==0 ){ return; }
	GLMovieTexture *instance = GetInstance(instanceId);
	[instance play];
}

void _Pause(uint64_t instanceId){
	DUMP("Pause(%llx)",instanceId);
	if( instanceId==0 ){ return; }
	GLMovieTexture *instance = GetInstance(instanceId);
	[instance pause];
}

float _CurrentTime(uint64_t instanceId){
	DUMP("CurrentTime(%llx)",instanceId);
	if( instanceId==0 ){ return 0.f; }
	GLMovieTexture *instance = GetInstance(instanceId);
	return instance.currentTime;
}

void _SetCurrentTime(uint64_t instanceId,float t){
	DUMP("SetCurrentTime(%llx,%f)",instanceId,t);
	if( instanceId==0 ){ return; }
	GLMovieTexture *instance = GetInstance(instanceId);
	instance.currentTime = t;
}

uint8_t _Loop(uint64_t instanceId){
	DUMP("Loop(%llx)",instanceId);
	if( instanceId==0 ){ return 0; }
	GLMovieTexture *instance = GetInstance(instanceId);
	return (uint8_t)instance.loop;
}

void _SetLoop(uint64_t instanceId,uint8_t loop){
	DUMP("SetLoop(%llx,%d)",instanceId,loop);
	if( instanceId==0 ){ return; }
	GLMovieTexture *instance = GetInstance(instanceId);
	instance.loop = (BOOL)loop;
}

//////////////////////////////////////////

static int FindEmbedData(FILE *fp,const char *chunkId);

static NSString* GetMoviePath(const char *name){
	NSString *basePath = [NSString stringWithFormat:@"%@/Data/Raw/%s",[[NSBundle mainBundle] resourcePath],name];
	NSString *path = [basePath stringByAppendingPathExtension:@"mov"];
	if( [[NSFileManager defaultManager] fileExistsAtPath:path] ){
		return path;
	}
	path = [basePath stringByAppendingPathExtension:@"png"];
	if( ![[NSFileManager defaultManager] fileExistsAtPath:path] ){
		return nil;
	}
	NSString *moviePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%s.mov",name]];
	
	FILE *fp = fopen([path UTF8String],"rb");
	
	int length = FindEmbedData(fp,EMBEDED_MOVIE_CHUNK_ID);
	if( length <= 0 ){
		return nil;
	}
	const int buffSize = 1024*1024;
	void *buff = malloc(buffSize);
	FILE *fo = fopen([moviePath UTF8String],"wb");
	
	while( length > 0 ) {
		int r = 0;
		if( buffSize < length ){
			r = fread(buff, 1, buffSize, fp);
		}else{
			r = fread(buff, 1, length, fp);
		}
		if( r <= 0 ){ break; }
		fwrite(buff, 1, r, fo);
		length -= r;
	}
	fclose(fo);
	fclose(fp);
	free(buff);
	
	return moviePath;
}

#define MKDW(a,b,c,d) (((a)<<24)|((b)<<16)|((c)<<8)|(d))
#define RDDW(p) MKDW(*(p),*(p+1),*(p+2),*(p+3))
#define IEND MKDW('I','E','N','D')

static int FindEmbedData(FILE *fp,const char *chunkId)
{
	if( !fp ){ return 0; }
	fseek(fp, 8, SEEK_SET);
	uint8_t buff[8];
	uint32_t type = 0;
	uint32_t embid = RDDW(chunkId);
	while(fread(buff, 8, 1, fp)==1){
		uint32_t length = RDDW(buff);
		type = RDDW(buff+4);
		if( type == IEND ){
			break;
		}else if( type == embid ){
			return length;
		}
		fseek(fp, length+4, SEEK_CUR);
	}	
	return 0;
}