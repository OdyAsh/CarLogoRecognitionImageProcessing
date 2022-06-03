function varargout = waitbar(varargin)
    if nargin >= 2 && ischar(varargin{2})
        disp(varargin{2})
    elseif nargin >= 3 && ischar(varargin{3})
        disp(varargin{3})
    end
    varargout = {[]};
end
%This function is overriding the built-in waitbar() function
%The output is sometimes like this: {[0]}    {'Applying neighborhood operation...'}
%Therefore we use the first if.
%And sometimes the output has "Applying ///" as the third argument
%Therefore we have the elseif.
%And since we aren't interested in any outputs, we put varargout = {[]};