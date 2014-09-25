/* Serialized Data File Logger
 *
 */

#include <stdio.h>
#include <string.h> /* For strcmp() */
#include <stdlib.h> /* For EXIT_FAILURE, EXIT_SUCCESS */

#include <math.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/stat.h>
#include <time.h>
#include <inttypes.h>
#include <signal.h>

#include <argp.h>

// local includes
#include "utils.h"
#include "signal.h"
#include "writer.h"
#include "parser.h"
#include "network.h"
#include "signalLogger.h"

NetworkAddress recvAddr;

error_t parse_opt(int key, char *arg, struct argp_state *state) {
    switch(key) {
        case 'r':
            parseNetworkAddress(arg, &recvAddr);
            break;
        case 'd':
            setDataRoot(arg);
            break;
        default:
            return ARGP_ERR_UNKNOWN;
    }
    return 0;
}

void abortFromMain(int sig) {
    printf("Data logger terminating\n");
    signalWriterThreadTerminate();
    networkReceiveThreadTerminate();
    controlTerminate();
    exit(EXIT_SUCCESS);
}

int main(int argc, char *argv[])
{
    // defaults
    setNetworkAddress(&recvAddr, "", "", 28000);

    // parse startup options
    struct argp_option options[] =
    {
        { "recv", 'r', "IP:PORT or PORT", 0, "Specify IP address and port to receive packets"},
        { "dataroot", 'd', "PATH", 0, "Specify data root folder"},
        { 0 }
    };
    struct argp argp = { options, parse_opt, 0, 0 };
    int status = argp_parse(&argp, argc, argv, 0, 0, 0);

	// copy the default data root in, later make this an option?
	if (!checkDataRootAccessible()) {
	    fprintf(stderr, "No read/write access to data root. Check writer permissions on %s", getDataRoot());
		exit(1);
	}

	logInfo("Info: signal data root at %s\n", getDataRoot());
    // Register <C-c> handler
    signal(SIGINT, abortFromMain);

    // initialize signal processing buffers and lookup tries
    // true means wait until NextTrial is received before buffering anything
    controlInitialize(true);

    signalWriterThreadStart();

    networkSetPacketReceivedCallbackFn(&processReceivedPacketData);

    status = networkReceiveThreadStart(&recvAddr);
    if(status > 0) {
        abortFromMain(0);
        exit(1);
    }

    while(1) {
        sleep(1);
    }

    abortFromMain(0);
    return(EXIT_SUCCESS);
}

