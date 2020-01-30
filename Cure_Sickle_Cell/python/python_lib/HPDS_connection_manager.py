import os


class tokenManager: 
    
    def __init__(self, token_file):
        self.token_file = token_file
                
    def get_token(self):
        if os.path.isfile(self.token_file):
            with open(self.token_file, "r") as f:
                __token__ = f.read()
                if len(__token__) == 0:
                    raise ValueError("Token file is empty")
                else:
                    print("\x1b[32m")
                    print("Security Token Imported Correctly")
                    return __token__
        else:
            print("{0} is not a valid file path".format(token_file))
            print("Please be sure to review python_PIC-SURE_API_101.ipynb to know how to import an user-specific security token")
            raise ValueError()
        return 
