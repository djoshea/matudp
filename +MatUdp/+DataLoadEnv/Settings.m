classdef Settings
    methods(Static)
        % subject, data, and data store root are mutually exclusive. set
        % only one.
        function setSubjectRoot(r)
            setenv('MATUDP_SUBJECTROOT', r);
            setenv('MATUDP_DATAROOT');
            setenv('MATUDP_DATASTOREROOT');
        end
        
        function setDataRoot(r)
            setenv('MATUDP_DATAROOT', r);
            setenv('MATUDP_SUBJECTROOT');
            setenv('MATUDP_DATASTOREROOT');
        end
        
        function setDataStoreRoot(r)
            setenv('MATUDP_DATASTOREROOT', r);
            setenv('MATUDP_DATAROOT');
            setenv('MATUDP_SUBJECTROOT');
        end
        
        function setSubject(r)
            setenv('MATUDP_SUBJECT', r);
        end
        
        function setProtocol(r)
            setenv('MATUDP_PROTOCOL', r);
        end
    end
end
