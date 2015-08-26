/*
 *   xpcnbexpose.c - xPC Target Network Buffer Expose block
 *
 *   Modified by Dan O'Shea (2015) from xpcnbunlink.c to produce pointer to data buffer as well
 *
 *   Copyright 2008-2009 The MathWorks, Inc.
*/

// build using:
// mex('xpcnbexpose.c', '-DMATLAB_MEX_FILE', ['-I' fullfile(matlabroot, 'toolbox\rtw\targets\xpc\target\build\xpcblocks\include')])

#define S_FUNCTION_LEVEL   2
#undef  S_FUNCTION_NAME
#define S_FUNCTION_NAME    xpcnbexpose

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

typedef enum {
   S_LENGTH = 0,
   NUM_S_PARAMS
} s_params;

static char_T     msg[256];
static int_T      j;
static xpcNBError error;

static void mdlInitializeSizes(SimStruct *S)
{
   ssSetNumSFcnParams(S, NUM_S_PARAMS);
   if (ssGetNumSFcnParams(S) != ssGetSFcnParamsCount(S)) {
      sprintf(msg, "%d input args expected, %d passed", NUM_S_PARAMS, ssGetSFcnParamsCount(S));
      ssSetErrorStatus(S, msg);
      return;
   }

   ssSetNumContStates(S, 0);
   ssSetNumDiscStates(S, 0);

   if ( ! ssSetNumInputPorts(S, 1) ) return;

   ssSetInputPortDataType(S, 0, SS_UINT32);
   ssSetInputPortWidth(S, 0, 1);
   ssSetInputPortRequiredContiguous(S, 0, 1);
   ssSetInputPortDirectFeedThrough(S, 0, 1);

   // adding second output port for actual data pointers
   // and a third output port for the actual data length
   if ( ! ssSetNumOutputPorts(S, 3) ) return;
   ssSetOutputPortDataType(S, 0, SS_UINT32);
   ssSetOutputPortWidth(S, 0, (int_T)mxGetPr(ssGetSFcnParam(S,S_LENGTH))[0]);
   ssSetOutputPortDataType(S, 1, SS_UINT32); // same size as nb output
   ssSetOutputPortWidth(S, 1, (int_T)mxGetPr(ssGetSFcnParam(S,S_LENGTH))[0]);
   ssSetOutputPortDataType(S, 2, SS_UINT32); // same size as nb output
   ssSetOutputPortWidth(S, 2, (int_T)mxGetPr(ssGetSFcnParam(S,S_LENGTH))[0]);

   ssSetNumSampleTimes(S, 1);
   ssSetNumIWork(S, 0);
   ssSetNumRWork(S, 0);
   ssSetNumPWork(S, 0);
   ssSetNumModes(S, 0);
   ssSetNumNonsampledZCs(S, 0);

   ssSetSimStateCompliance(S, HAS_NO_SIM_STATE);

   for ( j = 0 ; j < NUM_S_PARAMS ; j++ )
      ssSetSFcnParamTunable(S, j, SS_PRM_NOT_TUNABLE);

   ssSetOptions(S, SS_OPTION_DISALLOW_CONSTANT_SAMPLE_TIME | SS_OPTION_RUNTIME_EXCEPTION_FREE_CODE);
}

static void mdlInitializeSampleTimes(SimStruct *S)
{
   ssSetSampleTime(S, 0, INHERITED_SAMPLE_TIME);
   ssSetOffsetTime(S, 0, FIXED_IN_MINOR_STEP_OFFSET);
}

#ifdef MATLAB_MEX_FILE
#define MDL_SET_INPUT_PORT_WIDTH
static void mdlSetInputPortWidth(SimStruct *S, int_T port, int_T width)
{
}
#endif

#ifdef MATLAB_MEX_FILE
#define MDL_SET_OUTPUT_PORT_WIDTH
static void mdlSetOutputPortWidth(SimStruct *S, int_T port, int_T width)
{
   ssSetOutputPortWidth(S, port, width);
}
#endif

#ifdef MATLAB_MEX_FILE
#define MDL_SET_DEFAULT_PORT_WIDTH
static void mdlSetDefaultPortWidth(SimStruct *S)
{
   ssSetOutputPortWidth(S, 0, 1);
}
#endif

static void mdlOutputs(SimStruct *S, int_T tid)
{
#ifndef MATLAB_MEX_FILE
   xpcNB    *InChain, *OutBuffer;
   uint32_T *InputPort, *OutputPort, *DataOutputPort, *DataLenOutputPort;
   int32_T dataLen;

   InputPort  = (uint32_T*)ssGetInputPortSignal(S, 0);
   InChain = (xpcNB*)*InputPort;
   if ( error = xpcNBAccept(InChain) ) {
      sprintf(msg, "Network Buffer Unlink Error %d", error);
      ssSetErrorStatus(S, msg);
      return;
   }

   OutputPort = (uint32_T*)ssGetOutputPortSignal(S, 0);
   DataOutputPort = (uint32_T*)ssGetOutputPortSignal(S, 1);
   DataLenOutputPort = (uint32_T*)ssGetOutputPortSignal(S, 2);
   for ( j = 0 ; j < ssGetOutputPortWidth(S, 0) ; j++ ) {
      if ( error = xpcNBSplitChain(InChain, (int32_T)1, &OutBuffer, &InChain) ) {
         sprintf(msg, "Network Buffer Unlink Error %d", error);
         ssSetErrorStatus(S, msg);
         return;
      }
      
      OutputPort[j] = (uint32_T)OutBuffer;
      
      // @djoshea modified portion: extract the data pointer from the out buffer as well
      if(OutBuffer) {
          DataOutputPort[j] = (uint32_T)xpcNBData(OutBuffer);
          dataLen = (int32_T)xpcNBBytes(OutBuffer);
          if (dataLen < 0 ) dataLen = 0;
          DataLenOutputPort[j] = (uint32_T)dataLen;
          
          if ( error = xpcNBRelease(OutBuffer) ) {
             sprintf(msg, "Network Buffer Link Error %d", error);
             ssSetErrorStatus(S, msg);
             return;
          }
      } else {
          DataOutputPort[j] = (uint32_T) NULL;
          DataLenOutputPort[j] = (uint32_T) 0;
      }

      
   }

   if ( error = xpcNBFree(InChain) ) {
      sprintf(msg, "Network Buffer Link Error %d", error);
      ssSetErrorStatus(S, msg);
      return;
   }
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
