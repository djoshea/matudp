/*
 *
 *   xpcnbfree.c - based on NB Extract, except only frees the buffer
 *   Dan O'Shea 2015
 *   based on xpcnbextract.c - Simulink Real-Time Network Buffer Extract Block
 *
 *   Copyright 2008-2014 The MathWorks, Inc.
*/

// build using:
// mex('xpcnbfree.c', '-DMATLAB_MEX_FILE', ['-I' fullfile(matlabroot, 'toolbox\rtw\targets\xpc\target\build\xpcblocks\include')])


#define S_FUNCTION_LEVEL   2
#undef  S_FUNCTION_NAME
#define S_FUNCTION_NAME    xpcnbfree

#include <stddef.h>
#include <stdlib.h>
#include "simstruc.h"

#ifndef MATLAB_MEX_FILE
#include <windows.h>
#include "xpctarget.h"
#endif

#ifdef MATLAB_MEX_FILE
#include "mex.h"
#endif

#include "nblib.h"

static char_T     msg[256];
static int_T      j;
static xpcNBError error;


static void mdlInitializeSizes(SimStruct *S)
{
   ssSetNumSFcnParams(S, 0);
   if (ssGetNumSFcnParams(S) != ssGetSFcnParamsCount(S)) {
      sprintf(msg, "%d input args expected, %d passed", 0, ssGetSFcnParamsCount(S));
      ssSetErrorStatus(S, msg);
      return;
   }

   ssSetNumContStates(S, 0);
   ssSetNumDiscStates(S, 0);

   if ( ! ssSetNumInputPorts(S, 1) ) return;
   ssSetInputPortDataType(S, 0, SS_UINT32);
   ssSetInputPortWidth(S, 0, DYNAMICALLY_SIZED);
   ssSetInputPortRequiredContiguous(S, 0, 1);
   ssSetInputPortDirectFeedThrough(S, 0, 1);

   if ( ! ssSetNumOutputPorts(S, 0) ) return;

   ssSetNumSampleTimes(S, 1);
   ssSetNumIWork(S, 0);
   ssSetNumRWork(S, 0);
   ssSetNumPWork(S, 0);
   ssSetNumModes(S, 0);
   ssSetNumNonsampledZCs(S, 0);

   ssSetSimStateCompliance(S, HAS_NO_SIM_STATE);

   ssSetOptions(S, SS_OPTION_DISALLOW_CONSTANT_SAMPLE_TIME | SS_OPTION_RUNTIME_EXCEPTION_FREE_CODE);
}

static void mdlInitializeSampleTimes(SimStruct *S)
{
   ssSetSampleTime(S, 0, INHERITED_SAMPLE_TIME);
   ssSetOffsetTime(S, 0, FIXED_IN_MINOR_STEP_OFFSET);
   ssSetModelReferenceSampleTimeInheritanceRule(S, USE_DEFAULT_FOR_DISCRETE_INHERITANCE);
}

#ifdef MATLAB_MEX_FILE
#define MDL_SET_INPUT_PORT_WIDTH
static void mdlSetInputPortWidth(SimStruct *S, int_T port, int_T width)
{
    ssSetInputPortWidth(S, port, width);
}
#endif

#ifdef MATLAB_MEX_FILE
#define MDL_SET_OUTPUT_PORT_WIDTH
static void mdlSetOutputPortWidth(SimStruct *S, int_T port, int_T width)
{
   ssSetOutputPortWidth(S, port, width);
}
#endif

// #ifdef MATLAB_MEX_FILE
// #define MDL_SET_DEFAULT_PORT_WIDTH
// static void mdlSetDefaultPortWidth(SimStruct *S)
// {
//   // ssSetOutputPortWidth(S, 0, 64);
// }
// #endif

static void mdlOutputs(SimStruct *S, int_T tid)
{
#ifndef MATLAB_MEX_FILE
   uint32_T *InputPtr;
   xpcNB    *Buffer;

   // Get Buffer
   InputPtr = (uint32_T*)ssGetInputPortSignal(S, 0);

   for ( j = 0 ; j < ssGetInputPortWidth(S, 0) ; j++ ) {
      Buffer = (xpcNB*)InputPtr[j];
      if(Buffer) {
           // Free Buffer
           if ( error = xpcNBFree(Buffer) ) {
              sprintf(msg, "Network Buffer Extract Free Error %d", error);
              ssSetErrorStatus(S, msg);
              return;
           }
      }
   }
#else
//    real_T   *LengthPtr;

//    LengthPtr = (real_T*)ssGetOutputPortRealSignal(S, 1);
//    ssGetOutputPortSignal(S, 0) = 0;
//    *LengthPtr = 0;
#endif
}

static void mdlTerminate(SimStruct *S)
{
}


#ifdef MATLAB_MEX_FILE
#include "simulink.c"
#else
#include "cg_sfun.h"
#endif
