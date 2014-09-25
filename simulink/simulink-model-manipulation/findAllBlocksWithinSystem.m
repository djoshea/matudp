function h = findAllBlocksWithinSystem(sys)

if nargin < 2
    sys = bdroot;
end

h = find_system(sys, 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'Type', 'block');

end