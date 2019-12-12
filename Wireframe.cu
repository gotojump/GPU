#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

#include <math.h>

#include <iostream>
#include <vector>
#include <limits>

#include <time.h>
#include <sys/time.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>
#include <X11/extensions/Xrandr.h>
#include <X11/extensions/Xfixes.h>

using namespace std;

#define Max( n1, n2 )							( ( n1 ) > ( n2 ) ? ( n1 ) : ( n2 ) )
#define Min( n1, n2 )							( ( n1 ) < ( n2 ) ? ( n1 ) : ( n2 ) )

#define Abs( Nn )									( Nn < 0 ? -Nn : Nn )
#define IsNumber( Ch )							( ( Ch >= '0' ) && ( Ch <= '9' ) )

#define PI       3.14159265
#define PVAL	   ( PI / 180 )

#define ALPHA		3
#define RED			2
#define GREEN		1
#define BLUE		0

// --------------------------------------------------------------------- //

typedef struct Float3{
	float X, Y, Z;
}Float3;

typedef struct Face{
	uint32_t f[ 5 ];
}Face;

// --------------------------------------------------------------------- //

struct Canvas{
	uint32_t* Pixels;
	uint32_t* GPUPixels;
	uint32_t  Nx, Ny;

	bool OpenWindow;
	Display *Dsp;
	XSetWindowAttributes Wa;
	XVisualInfo Vi;
	Window Win;
	XImage* Xim;
	GC Gc;
};

// --------------------------------------------------------------------- //

struct Object{
	std::vector<Face>   Faces;
	std::vector<Float3> Verts;
	std::vector<Float3> PerspVerts;

	Float3*  GPUVerts;
	Face*    GPUFaces;

	uint32_t N_Verts, N_Faces;
};

// --------------------------------------------------------------------- //

Canvas   CreateCanvas( uint32_t _Nx, uint32_t _Ny, bool OpenWindow );
void     FreeCanvas( Canvas& Cnv );
void     ClearCanvas( Canvas& Cnv );
void     FlipCanvas( Canvas& Cnv );
void     SaveCanvas( Canvas& Cnv, const char* FileName );

// --------------------------------------------------------------------- //

uint64_t TimeGet();
int      GetInt( FILE* Fl );
Object   Read( char* Path );
void     Print( Object& Obj );

void     DrawLine( Canvas& Cnv, int Px1, int Py1, float Pz1, int Px2, int Py2, float Pz2 );
void     RotateAndDrawObject( Canvas& Cnv, Object& Obj, Float3 Cam, float Rotate );

// --------------------------------------------------------------------- //

__global__ void GPURotateAndDrawObject( Canvas Cnv, Object Obj, Float3 Cam, float Rotate ){
	int Nf = blockIdx.x;
	int Nv = threadIdx.x;

	float Scale, Prop, Sin, Cos;
	Float3 Dif, Persp1, Persp2;
	uint32_t P1, P2;

	float Px, Py, Pz, _Nx, _Ny, _Nz, Dz;
	uint32_t Color, *Pixels = NULL;
	int Dx, Dy, Nn, Nm;
	uint8_t ByteColor;

	if( !Cnv.Nx || !Cnv.Ny )
		return;

	Scale = ( Min( Cnv.Nx, Cnv.Ny ) / 2 );
	Sin = sin( Rotate * PVAL );
	Cos = cos( Rotate * PVAL );

	if( Nf < Obj.N_Faces ){
		if( Nv < 4 ){

			P1 = Obj.GPUFaces[ Nf ].f[ Nv ] - 1;
			P2 = Obj.GPUFaces[ Nf ].f[ Nv + 1 ] - 1;


			Persp1.X = ( Cos * Obj.GPUVerts[ P1 ].X - Sin * Obj.GPUVerts[ P1 ].Z );
			Persp1.Z = ( Sin * Obj.GPUVerts[ P1 ].X + Cos * Obj.GPUVerts[ P1 ].Z );
			Persp1.Y = -Obj.GPUVerts[ P1 ].Y;

			Prop = Abs( Cam.Z - Persp1.Z ) * 0.5;
			Prop = ( Prop == 0 ? 0.0001 : Prop );

			Dif.X = Persp1.X - Cam.X;
			Dif.Y = Persp1.Y - Cam.Y;

			Persp1.X = (float)( Cnv.Nx / 2.0 ) + ( Dif.X * Scale / Prop );
			Persp1.Y = (float)( Cnv.Ny / 2.0 ) + ( Dif.Y * Scale / Prop );


			Persp2.X = ( Cos * Obj.GPUVerts[ P2 ].X - Sin * Obj.GPUVerts[ P2 ].Z );
			Persp2.Z = ( Sin * Obj.GPUVerts[ P2 ].X + Cos * Obj.GPUVerts[ P2 ].Z );
			Persp2.Y = -Obj.GPUVerts[ P2 ].Y;

			Prop = Abs( Cam.Z - Persp2.Z ) * 0.5;
			Prop = ( Prop == 0 ? 0.0001 : Prop );

			Dif.X = Persp2.X - Cam.X;
			Dif.Y = Persp2.Y - Cam.Y;

			Persp2.X = (float)( Cnv.Nx / 2.0 ) + ( Dif.X * Scale / Prop );
			Persp2.Y = (float)( Cnv.Ny / 2.0 ) + ( Dif.Y * Scale / Prop );


			Persp1.Z = Max( Min( Persp1.Z, 1.0 ), -1.0 );
			Persp2.Z = Max( Min( Persp2.Z, 1.0 ), -1.0 );


			Dx = Persp2.X - Persp1.X;
			Dy = Persp2.Y - Persp1.Y;
			Dz = Persp2.Z - Persp1.Z;

			Nn = Max( Abs( Dx ), Abs( Dy ) );
			if( !Nn )
				return;

			Px = (float)Dx / (float)Nn;
			Py = (float)Dy / (float)Nn;
			Pz = (float)Dz / (float)Nn;

			_Nx = Persp1.X;
			_Ny = Persp1.Y;
			_Nz = Persp1.Z;

			for( Nm = 0 ; Nm <= Nn ; Nm++ ){
				ByteColor = (int)( 255 * ( ( _Nz + 1.0 ) / 2.0 ) );
				Color = ( ByteColor << 16 ) | ( ByteColor << 8 ) | ByteColor;

				if( ( _Nx >= 0 ) && ( _Nx < Cnv.Nx ) && ( _Ny >= 0 ) && ( _Ny < Cnv.Ny ) ){
					Pixels = &Cnv.GPUPixels[ (int)_Nx + (int)_Ny * Cnv.Nx ];
					atomicMax( Pixels, Color );
				}
				_Nx += Px;
				_Ny += Py;
				_Nz += Pz;
			}
		}
	}
}

// --------------------------------------------------------------------- //

Canvas CreateCanvas( uint32_t _Nx, uint32_t _Ny, bool OpenWindow = false ){
	Canvas Cnv;
	int Nw, Nh;
	uint64_t Att;
	uint32_t Ns;

	memset( (void*)&Cnv, 0, sizeof( Canvas ) );

	if( !_Nx || !_Ny )
		_Nx = _Ny = 400;

	Cnv.Pixels = (uint32_t*)malloc( 4 * _Nx * _Ny );
	if( !Cnv.Pixels ){
		puts( "Falha ao alocar memória!!" );
		exit( 0 );
	}

  cudaMalloc( (void **)&Cnv.GPUPixels, 4 * _Nx * _Ny );

	Cnv.Nx = _Nx;
	Cnv.Ny = _Ny;

	ClearCanvas( Cnv );

	if( OpenWindow == true ){

		Cnv.Dsp = XOpenDisplay( NULL );
		if( !Cnv.Dsp ){
			puts( "ERRO: Problema ao abrir display da janela!" );
			return( Cnv );
		}

		Cnv.Wa.background_pixel = 0;
		Cnv.Wa.override_redirect = 1;

		Att = CWBackPixel | CWColormap;
		Ns = DefaultScreen( Cnv.Dsp );

		if( !XMatchVisualInfo( Cnv.Dsp, Ns, 24, TrueColor, &Cnv.Vi ) ){
			puts( "ERRO: Problema ao setar configuração da janela!" );
			return( Cnv );
		}

		Nw = ( DisplayWidth( Cnv.Dsp, Ns ) / 2 ) - (int)( _Nx / 2 );
		Nh = ( DisplayHeight( Cnv.Dsp, Ns ) / 2 ) - (int)( _Ny / 2 );
		Cnv.Win = XCreateWindow( Cnv.Dsp, RootWindow( Cnv.Dsp, Ns ), Nw, Nh, _Nx, _Ny, 0, Cnv.Vi.depth, InputOutput, Cnv.Vi.visual, Att, &Cnv.Wa );
		if( !Cnv.Win ){
			puts( "ERRO: Problema ao abrir janela!" );
			return( Cnv );
		}

		XSelectInput( Cnv.Dsp, Cnv.Win, ExposureMask | KeyPressMask | KeyReleaseMask | ButtonPressMask | ButtonReleaseMask );
		XStoreName( Cnv.Dsp, Cnv.Win, "Janelinha" );

		Cnv.Gc = XCreateGC( Cnv.Dsp, Cnv.Win, 0, NULL );
		XSetForeground( Cnv.Dsp, Cnv.Gc, 0 );

		Atom At = XInternAtom( Cnv.Dsp , "_NET_WM_STATE", 0 );
		XSetWMProtocols( Cnv.Dsp, Cnv.Win, &At, 1 );
		XMapWindow( Cnv.Dsp, Cnv.Win );

		if( Cnv.Xim ){
			XDestroyImage( Cnv.Xim );
			Cnv.Xim = NULL;
		}

		XResizeWindow( Cnv.Dsp, Cnv.Win, _Nx, _Ny );

		Cnv.Xim = XCreateImage( Cnv.Dsp, Cnv.Vi.visual, Cnv.Vi.depth, ZPixmap, 0, (char*)Cnv.Pixels, _Nx, _Ny, 32, 0 );
		if( !Cnv.Xim ){
			puts( "ERRO: Problema ao setar imagem!" );
			return( Cnv );
		}

		XFlush( Cnv.Dsp );
		XSync( Cnv.Dsp, 0 );
		XPending( Cnv.Dsp );
		usleep( 200000 );

		Cnv.OpenWindow = true;
	}

	return( Cnv );
}

// --------------------------------------------------------------------- //

void FreeCanvas( Canvas& Cnv ){

	if( Cnv.OpenWindow == true ){
		if( Cnv.Xim ){
			XDestroyImage( Cnv.Xim );
			Cnv.Xim = NULL;
		}
		if( Cnv.Dsp ){
			XCloseDisplay( Cnv.Dsp );
			Cnv.Dsp = NULL;
		}
	}
	else
		if( Cnv.Pixels ){
			free( Cnv.Pixels );
			cudaFree( Cnv.GPUPixels );
		}

	memset( (void*)&Cnv, 0, sizeof( Canvas ) );
}

// --------------------------------------------------------------------- //

void ClearCanvas( Canvas& Cnv ){

	if( Cnv.Pixels )
		memset( (void*)Cnv.Pixels, 0, 4 * Cnv.Nx * Cnv.Ny );
	cudaMemset( Cnv.GPUPixels, 0, 4 * Cnv.Nx * Cnv.Ny );
}

// --------------------------------------------------------------------- //

void FlipCanvas( Canvas& Cnv ){

	if( !Cnv.Xim || !Cnv.Dsp )
		return;

	XPutImage( Cnv.Dsp, Cnv.Win, Cnv.Gc, Cnv.Xim, 0, 0, 0, 0, Cnv.Nx, Cnv.Ny );
}

// --------------------------------------------------------------------- //

void SaveCanvas( Canvas& Cnv, const char* FileName ){
	uint8_t* Data = NULL;
	FILE* Fl = NULL;
	int Nn;

	if( !FileName ){
		puts( "Sem filename!!" );
		return;
	}

	Fl = fopen( FileName, "w" );
	if( !Fl ){
		puts( "Erro ao abrir arquivo!!" );
		return;
	}

	fprintf( Fl, "P6\n%d %d\n255\n", Cnv.Nx, Cnv.Ny );
	for( Nn = 0, Data = (uint8_t*)Cnv.Pixels ; Nn < Cnv.Nx * Cnv.Ny ; Nn++, Data += 4 ){
		fwrite( Data + RED  , 1, 1, Fl );
		fwrite( Data + GREEN, 1, 1, Fl );
		fwrite( Data + BLUE , 1, 1, Fl );
	}

	fclose( Fl );
}

// --------------------------------------------------------------------- //

uint64_t TimeGet(){
	struct timeval tv;
	uint64_t Clk;

	gettimeofday( &tv, NULL );
	Clk = 1000000 * tv.tv_sec + tv.tv_usec;

	return( Clk );
}

// --------------------------------------------------------------------- //

int GetInt( FILE* Fl ){
	char Ch;
	int Nn;

	if( !Fl )
		return( 0 );

	Nn = 0;

	do{
		Ch = fgetc( Fl );
		if( Ch == '\n' )
			return( 0 );
	}while( !IsNumber( Ch ) && !feof( Fl ) );

	do{
		Nn = ( Nn * 10 ) + ( Ch - '0' );
		Ch = fgetc( Fl );
		if( Ch == '/' ){
			do{
				Ch = fgetc( Fl );
			}while( ( Ch != '\n' ) && ( Ch != ' ' ) && !feof( Fl ) );
		}
	}while( IsNumber( Ch ) && !feof( Fl ) );

	fseek( Fl, -1, SEEK_CUR );

	return( Nn );
}

// --------------------------------------------------------------------- //

Object Read( char* Path ){
	Float3 Vmin, Vmax, Dif;
	FILE* Fl = NULL;
	int Size, Nn, Nm;
	float Mn, Prop;
	Object Obj;
	Float3 Nf;
	char Ch;

	if( Path == NULL ){
		puts( "ERRO: Nome do arquivo nulo!" );
		exit( 0 );
	}

	Fl = fopen( Path, "rb" );
	if( Fl == NULL ){
		puts( "ERRO: Arquivo inexistente!" );
		exit( 0 );
	}

	Mn = 0.0;
	Vmin.X = Vmin.Y = Vmin.Z = std::numeric_limits<float>::max();
	Vmax.X = Vmax.Y = Vmax.Z = std::numeric_limits<float>::min();

	// Lendo vertices e faces
	while( !feof( Fl ) ){
		Ch = fgetc( Fl );

		switch( Ch ){

		case( 'v' ):
			if( ( Ch = fgetc( Fl ) ) != ' ' ){
				while( ( Ch != '\n' ) && !feof( Fl ) )
					Ch = fgetc( Fl );
				break;
			}
			fscanf( Fl, "%f %f %f\n", &Nf.X, &Nf.Y, &Nf.Z );

			Size = Obj.Verts.size();
			Obj.Verts.resize( Size + 1 );
			Obj.Verts[ Size ].X = Nf.X;
			Obj.Verts[ Size ].Y = Nf.Y;
			Obj.Verts[ Size ].Z = Nf.Z;

			Vmin.X = Min( Vmin.X, Nf.X );
			Vmax.X = Max( Vmax.X, Nf.X );

			Vmin.Y = Min( Vmin.Y, Nf.Y );
			Vmax.Y = Max( Vmax.Y, Nf.Y );

			Vmin.Z = Min( Vmin.Z, Nf.Z );
			Vmax.Z = Max( Vmax.Z, Nf.Z );
		break;

		case( 'f' ):
			Size = Obj.Faces.size();
			Obj.Faces.resize( Size + 1 );

			Nm = 0;
			while( ( Nn = GetInt( Fl ) ) != 0 ){
				Obj.Faces[ Size ].f[ Nm ] = Nn;
				Nm++;
			}
			for( Nn = 0 ; Nm < 5 ; Nn++, Nm++ )
				Obj.Faces[ Size ].f[ Nm ] = Obj.Faces[ Size ].f[ Nn ];

		break;

		case( '#' ):
		default:
			while( ( Ch != '\n' ) && !feof( Fl ) )
				Ch = fgetc( Fl );
		break;
		}
	}

	// Alocando vetor

	Obj.N_Verts = Obj.Verts.size();
	Obj.N_Faces = Obj.Faces.size();


	Obj.PerspVerts.resize( Obj.N_Verts );

	// Centralizando imagem
	Dif.X = Vmin.X + ( ( Vmax.X - Vmin.X ) / 2 );
	Dif.Y = Vmin.Y + ( ( Vmax.Y - Vmin.Y ) / 2 );
	Dif.Z = Vmin.Z + ( ( Vmax.Z - Vmin.Z ) / 2 );

	Mn = 0;
	for( Nn = 0 ; Nn < (int)Obj.N_Verts ; Nn++ ){
		Obj.Verts[ Nn ].X -= Dif.X;
		Obj.Verts[ Nn ].Y -= Dif.Y;
		Obj.Verts[ Nn ].Z -= Dif.Z;

		Mn = ( Mn > Abs( Obj.Verts[ Nn ].X ) ? Mn : Obj.Verts[ Nn ].X );
		Mn = ( Mn > Abs( Obj.Verts[ Nn ].Y ) ? Mn : Obj.Verts[ Nn ].Y );
		Mn = ( Mn > Abs( Obj.Verts[ Nn ].Z ) ? Mn : Obj.Verts[ Nn ].Z );
	}

	// Redimensionando imagem para o intervalo [-1.0, 1.0]
	Prop = 1.0 / Mn;
	for( Nn = 0 ; Nn < (int)Obj.N_Verts ; Nn++ ){
		Obj.Verts[ Nn ].X *= Prop;
		Obj.Verts[ Nn ].Y *= Prop;
		Obj.Verts[ Nn ].Z *= Prop;
	}

	// Gerando alocações da GPU

  cudaMalloc( (void **)&Obj.GPUFaces, Obj.N_Faces * sizeof( Face ) );
  cudaMalloc( (void **)&Obj.GPUVerts, Obj.N_Verts * sizeof( Float3 ) );
	if( !Obj.GPUFaces || !Obj.GPUVerts ){
		puts( "Falha de alocação!!" );
		exit( 0 );
	}

	cudaMemcpy( Obj.GPUFaces, &Obj.Faces[ 0 ], Obj.N_Faces * sizeof( Face ), cudaMemcpyHostToDevice );
	cudaMemcpy( Obj.GPUVerts, &Obj.Verts[ 0 ], Obj.N_Verts * sizeof( Float3 ), cudaMemcpyHostToDevice );

	return( Obj );
}

// --------------------------------------------------------------------- //

void Print( Object& Obj ){
	uint32_t Nn, Nm;

	for( Nn = 0 ; Nn < Obj.N_Verts ; Nn++ )
		printf( "Point %d: %f %f %f\n", Nn, Obj.Verts[ Nn ].X, Obj.Verts[ Nn ].Y, Obj.Verts[ Nn ].Z );

	for( Nn = 0 ; Nn < Obj.N_Faces ; Nn++ ){
		printf( "Face %d: ", Nn );
		for( Nm = 0 ; Obj.Faces[ Nn ].f[ Nm ] ; Nm++ )
			printf( "%d ", Obj.Faces[ Nn ].f[ Nm ] - 1 );
		printf( "\n" );
	}
}

// --------------------------------------------------------------------- //

void DrawLine( Canvas& Cnv, int Px1, int Py1, float Pz1, int Px2, int Py2, float Pz2 ){
	float Px, Py, Pz, _Nx, _Ny, _Nz, Dz;
	uint32_t Color, *Pixels = NULL;
	int Dx, Dy, Nn, Nm;
	uint8_t ByteColor;

	if( !Cnv.Pixels )
		return;

	Pz1 = Max( Min( Pz1, 1.0 ), -1.0 );
	Pz2 = Max( Min( Pz2, 1.0 ), -1.0 );

	Dx = Px2 - Px1;
	Dy = Py2 - Py1;
	Dz = Pz2 - Pz1;

	Nn = Max( Abs( Dx ), Abs( Dy ) );
	if( !Nn )
		return;

	Px = (float)Dx / (float)Nn;
	Py = (float)Dy / (float)Nn;
	Pz = (float)Dz / (float)Nn;

	_Nx = Px1;
	_Ny = Py1;
	_Nz = Pz1;

	for( Nm = 0 ; Nm <= Nn ; Nm++ ){
		ByteColor = (int)( 255 * ( ( _Nz + 1.0 ) / 2.0 ) );
		Color = ( ByteColor << 16 ) | ( ByteColor << 8 ) | ByteColor;

		if( ( _Nx >= 0 ) && ( _Nx < Cnv.Nx ) && ( _Ny >= 0 ) && ( _Ny < Cnv.Ny ) ){
			Pixels = &Cnv.Pixels[ (int)_Nx + (int)_Ny * Cnv.Nx ];
			*Pixels = Max( Color, *Pixels );
		}
		_Nx += Px;
		_Ny += Py;
		_Nz += Pz;
	}
}

// --------------------------------------------------------------------- //

void RotateAndDrawObject( Canvas& Cnv, Object& Obj, Float3 Cam, float Rotate ){
	float Scale, Prop, Sin, Cos;
	uint32_t P1, P2;
	Float3 Dif;
	int Nn, Nm;

	if( !Cnv.Nx || !Cnv.Ny )
		return;

	Scale = ( Min( Cnv.Nx, Cnv.Ny ) / 2 );
	Sin = sin( Rotate * PVAL );
	Cos = cos( Rotate * PVAL );

	for( Nn = 0 ; Nn < (int)Obj.N_Verts ; Nn++ ){

		Obj.PerspVerts[ Nn ].X = ( Cos * Obj.Verts[ Nn ].X - Sin * Obj.Verts[ Nn ].Z );
		Obj.PerspVerts[ Nn ].Z = ( Sin * Obj.Verts[ Nn ].X + Cos * Obj.Verts[ Nn ].Z );
		Obj.PerspVerts[ Nn ].Y = -Obj.Verts[ Nn ].Y;

		Prop = Abs( Cam.Z - Obj.PerspVerts[ Nn ].Z ) * 0.5;
		Prop = ( Prop == 0 ? 0.0001 : Prop );
		//printf( "Proportion: %f = %f - %f\n", Prop, Cam.Z, Verts[ Nn ].X );

		Dif.X = Obj.PerspVerts[ Nn ].X - Cam.X;
		Dif.Y = Obj.PerspVerts[ Nn ].Y - Cam.Y;

		Obj.PerspVerts[ Nn ].X = (float)( Cnv.Nx / 2.0 ) + ( Dif.X * Scale / Prop );
		Obj.PerspVerts[ Nn ].Y = (float)( Cnv.Ny / 2.0 ) + ( Dif.Y * Scale / Prop );
	}

	for( Nn = 0 ; Nn < (int)Obj.N_Faces ; Nn++ ){
		for( Nm = 0 ; Nm < 4 ; Nm++ ){
			P1 = Obj.Faces[ Nn ].f[ Nm ] - 1;
			P2 = Obj.Faces[ Nn ].f[ Nm + 1 ] - 1;
			DrawLine( Cnv, Obj.PerspVerts[ P1 ].X, Obj.PerspVerts[ P1 ].Y, Obj.PerspVerts[ P1 ].Z,
                     Obj.PerspVerts[ P2 ].X, Obj.PerspVerts[ P2 ].Y, Obj.PerspVerts[ P2 ].Z  );
		}
	}

}

// --------------------------------------------------------------------- //

void Help(){

	puts( "\t-s: Executa o algoritmo sequencial." );
	puts( "\t-f <file>: Especifica o algoritmo de entrada." );
	puts( "\t-r <N>: Especifica a quantidade de posições a serem geradas durante a rotação do objeto(180 por padrão)." );
	puts( "\t-w: Abre uma janela para exibir a projeção criada." );
	puts( "\t-x <N>: Altera a largura da tela(400 por padrão)." );
	puts( "\t-y <N>: Altera a altura da tela(400 por padrão)." );
	puts( "\t-p: Nome da pasta para salvar as imagens geradas." );
	puts( "\t-t: Define o número de vezes que o algoritmo será executado consecutivamente(1 por padrão)." );
	puts( "\t-h: Abre o menu de ajuda." );
}

// --------------------------------------------------------------------- //

int main( int Argc, char** Argv ){
	uint32_t Nrot = 180, Nx = 400, Ny = 400, Tests = 1, Nt;
	char Buff[ 64 ], *FileName = NULL, *Path = NULL;
	uint64_t T1, Total, Med;
	bool Seq, Win;
	Float3 Cam;
	Canvas Cnv;
	Object Obj;
	int Nn;

	if( Argc <= 1 ){
		puts( "Faltam argumentos:" );
		Help();

		return( 0 );
	}

	Seq = Win = false;

	for( Nn = 1 ; Nn < Argc ; Nn++ ){
		if( !strcmp( Argv[ Nn ], "-s" ) )
			Seq = true;

		if( !strcmp( Argv[ Nn ], "-w" ) )
			Win = true;

		if( !strcmp( Argv[ Nn ], "-h" ) ){
			Help();
			return( 0 );
		}

		if( ( !strcmp( Argv[ Nn ], "-f" ) ) && ( Argv[ Nn + 1 ] != NULL ) ){
			Nn++;
			FileName = Argv[ Nn ];
		}

		if( ( !strcmp( Argv[ Nn ], "-r" ) ) && ( Argv[ Nn + 1 ] != NULL ) ){
			Nn++;
			Nrot = atoi( Argv[ Nn ] );
		}

		if( ( !strcmp( Argv[ Nn ], "-x" ) ) && ( Argv[ Nn + 1 ] != NULL ) ){
			Nn++;
			Nx = atoi( Argv[ Nn ] );
		}

		if( ( !strcmp( Argv[ Nn ], "-y" ) ) && ( Argv[ Nn + 1 ] != NULL ) ){
			Nn++;
			Ny = atoi( Argv[ Nn ] );
		}

		if( ( !strcmp( Argv[ Nn ], "-t" ) ) && ( Argv[ Nn + 1 ] != NULL ) ){
			Nn++;
			Tests = atoi( Argv[ Nn ] );
		}

		if( ( !strcmp( Argv[ Nn ], "-p" ) ) && ( Argv[ Nn + 1 ] != NULL ) ){
			Nn++;
			Path = Argv[ Nn ];
		}
	}

	Cam.X = Cam.Y = 0;
	Cam.Z = 3;

	Obj = Read( FileName );

	printf( "%s: %u vertices e %u faces %s(%d posições).\n", FileName, Obj.N_Verts, Obj.N_Faces, Seq == true ? "sequencial" : "em paralelo", Nrot );
	//Print( Obj );

	Cnv = CreateCanvas( Nx, Ny, Win );

	Med = 0;
	for( Nt = 0 ; Nt < Tests ; Nt++ ){
		Total = 0;
		for( Nn = 0 ; Nn < Nrot ; Nn++ ){
			ClearCanvas( Cnv );

			if( Seq == true ){
				T1 = TimeGet();
				RotateAndDrawObject( Cnv, Obj, Cam, Nn * ( 360.0 / Nrot ) );
				Total += ( TimeGet() - T1 );
			}
			else{
				T1 = TimeGet();
				GPURotateAndDrawObject <<< Obj.N_Faces, 4 >>> ( Cnv, Obj, Cam, Nn * ( 360.0 / Nrot ) );
				cudaMemcpy( Cnv.Pixels, Cnv.GPUPixels, Cnv.Nx * Cnv.Ny * 4, cudaMemcpyDeviceToHost);		
				Total += ( TimeGet() - T1 );
			}

			if( Path != NULL ){
				sprintf( Buff, "%s/Image%d.ppm", Path, Nn );
				SaveCanvas( Cnv, Buff );
			}
			if( Win == true ){
				FlipCanvas( Cnv );
				usleep( 10000 );
			}
		}

		printf( "Tempo total gasto com processamento: %lu.%06lus\n", Total / 1000000, Total % 1000000 );
		Med += Total;
	}

	Med /= Tests;
	printf( "Tempo medio: %lu.%06lus\n", Med / 1000000, Med % 1000000 );

	FreeCanvas( Cnv );

	return( 0 );
}

// --------------------------------------------------------------------- //
