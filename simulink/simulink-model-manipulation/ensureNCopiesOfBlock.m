function blocks = ensureNCopiesOfBlock(rootBlock, blockPrefix, nDesired, varargin)
% Ensures that exactly N copies of a template block exist within a subsystem
%
% blocks = ensureNCopiesOfBlock(rootBlock, blockPrefix, nDesired, varargin)
% 
% Scans a subsystem (those blocks directly under rootBlock) for copies of a
% template block named like blockPrefix# where # is an integer. Ensures
% that the only such blocks that exist have # in the range 1:nDesired.
% Deletes blocks whose # falls outside this range, and creates new blocks
% based off the template with the appropriate names. The default template
% is blockPrefix1. If you request 0 copies, the template must not have a
% name like blockPrefix#, ensuring that the template itself is never
% deleted.
% 
% Returns:
%   blocks: the names of each block
%
% Optional parameters:
%   template: the template to make copies from [default [blockPrefix '1']]
%   vStart: the starting y position [default = y-pos of template]
%   hStart: the starting x position [default = x-pos of template]
%   vOffset: vertical offset between blocks [default = height of template + 20]
%   hOffset: horizontal offset between blocks [default = 0]
%
% All other parameters passed via varargin will be treated as block
% parameters. If the value provided is a function handle, the function will
% be evaluated as fn(blockNumber) to retrieve the value for that block.
% 

    p = inputParser;
    p.addParamValue('template', [blockPrefix '1'], @ischar);
    p.addParamValue('vStart', [], @isnumeric);
    p.addParamValue('hStart', [], @isnumeric);
    p.addParamValue('vOffset', [], @isnumeric);
    p.addParamValue('hOffset', [], @isnumeric);
    p.KeepUnmatched = true;
    p.parse(varargin{:});
   
    template = [rootBlock '/' p.Results.template];
    vOffset = p.Results.vOffset;
    hOffset = p.Results.hOffset;

    % check template
    assert(blockExists(template), 'Cannot find template block %s', template);
    
    % default offsets stacks each block beneath the previous one with a
    % small gap
    [~, height] = getBlockSize(template);
    if isempty(vOffset)
        vOffset = height + 20;
    end
    if isempty(hOffset)
        hOffset = 0;
    end
    
    fullBlockPrefix = [rootBlock, '/', blockPrefix];
    blockNameFn = @(i) [ fullBlockPrefix, num2str(i) ];
    blockType = getBlockType(template);
    
    % check whether we'd be deleting the template
    if strcmp(template, blockNameFn(1)) && nDesired < 1
        error('Removing all copies would delete the template block.');
    end
    
    % find the blocks inside with name "blockPrefix#"
    blocks = find_system(rootBlock, 'FollowLinks', 'on', 'LookUnderMasks', 'all', ...
        'SearchDepth', 1, 'Regexp', 'on', 'BlockType', blockType, 'Name', [blockPrefix '\d+']);
    nBlocks = numel(blocks);

    % loop through existing blocks and delete them if # outside 1:nDesired
    for i = 1:nBlocks
        bToDelete = blocks{i};

        num = regexp(bToDelete, [fullBlockPrefix '(\d+)'], 'tokens', 'once');
        num = str2double(num{1});

        if(num > nDesired)
            deleteOutgoingLine(bToDelete, 1);
            deleteBlock(bToDelete);
        end
    end
    
    % generate array of blockNames
    blocks = arrayfun(blockNameFn, (1:nDesired)', 'UniformOutput', false);
    
    blockParams = fieldnames(p.Unmatched);
    nBlockParams = numel(blockParams);
    
    % loop through the block names and create them if necessary from the
    % template with the appropriate positional offsets
    [x, y, width, height] = getBlockPosition(template);
    for iBlock = 1:nDesired
        % make block if it doesn't exist
        addBlockSafe(template, blocks{iBlock});
        
        % set the block parameters provided
        for iParam = 1:nBlockParams
            value = p.Unmatched.(blockParams{iParam});
            % if the value is a function handle, evaluate for this block
            if isa(value, 'function_handle')
                value = value(iBlock);
            end
            
            setBlockParam(blocks{iBlock}, blockParams{iParam}, value);
        end

        % position it at an offset from the last block
        setBlockPosition(blocks{iBlock}, x, y, width, height);
        x = x + hOffset;
        y = y + vOffset;
    end 


end
