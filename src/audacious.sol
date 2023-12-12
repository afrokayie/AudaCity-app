// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface DatafeedConsumer {
    function answer() external returns (uint256);

    function decimals() external returns (uint8);

    function getLatestData() external;
}

contract ERWA is ERC1155, AccessControl {
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address public treasury;

    struct TokenConfig {
        uint256 minTokens;
        uint256 maxTokens;
        uint256 usdPricePerToken; // 1 USD
        uint256 startDate;
        uint256 endDate;
        address admin;
        uint256 decimals;
    }
    event depositKlay(
        uint id,
        uint _amountPayed,
        address _user,
        uint _amountMinted
    );
    event mintRWA(
        address treasury,
        uint id,
        uint amount,
        uint256 minTokens,
        uint256 maxTokens,
        uint256 usdPricePerToken,
        uint256 startDate,
        uint256 endDate
    );

    mapping(address => bool) public userKyc;
    // NFTID => TokenConfig
    mapping(uint256 => TokenConfig) public tokenConfig;
    DatafeedConsumer datafeedAddress;

    constructor(address _datafeedAddress, address _treasury) ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(URI_SETTER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        treasury = _treasury;
        datafeedAddress = DatafeedConsumer(_datafeedAddress);
    }

    function setURI(string memory newuri) public onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
    }

    // function setKyc(address userAddr, bool flag) public onlyRole(MINTER_ROLE) {
    //     userKyc[userAddr] = flag;
    // }
    modifier isKycDone() {
        require(userKyc[msg.sender] == true, "KYC yet to be done");
        _;
    }

    function updateMin(
        uint256 id,
        uint256 minTokens
    ) public onlyRole(MINTER_ROLE) {
        tokenConfig[id].minTokens = minTokens;
    }

    function updateMax(
        uint256 id,
        uint256 maxTokens
    ) public onlyRole(MINTER_ROLE) {
        tokenConfig[id].maxTokens = maxTokens;
    }

    function updateUsdPricePerToken(
        uint256 id,
        uint256 usdPricePerToken
    ) public onlyRole(MINTER_ROLE) {
        tokenConfig[id].usdPricePerToken = usdPricePerToken;
    }

    function updateStartDate(
        uint256 id,
        uint256 startDate
    ) public onlyRole(MINTER_ROLE) {
        tokenConfig[id].startDate = startDate;
    }

    function updateEndDate(
        uint256 id,
        uint256 endDate
    ) public onlyRole(MINTER_ROLE) {
        tokenConfig[id].endDate = endDate;
    }

    function deposit(uint256 id) public payable {
        // allow only in specific timeframe
        TokenConfig storage _tokenConfig = tokenConfig[id];

        require(
            block.timestamp >= _tokenConfig.startDate &&
                block.timestamp <= _tokenConfig.endDate,
            "Cant deposit"
        );

        datafeedAddress.getLatestData();
        uint256 klayUsdPrice = datafeedAddress.answer();
        //find the no of tokens equivalent to klay -- openzepplin Math
        uint256 tokensToBeMinted = (msg.value * klayUsdPrice) /
            _tokenConfig.usdPricePerToken;

        //then check the conditions if its between min and max
        require(
            tokensToBeMinted > _tokenConfig.minTokens &&
                tokensToBeMinted <= _tokenConfig.maxTokens,
            "Min and Max not met"
        );
        // transfer from ProjectAdmin to the user
        IERC1155(this).safeTransferFrom(
            _tokenConfig.admin,
            msg.sender,
            id + 1,
            tokensToBeMinted,
            ""
        );
        // Emit event
        emit depositKlay(id, msg.value, msg.sender, tokensToBeMinted);
    }

    function mintRwa(
        uint256 id,
        uint256 amount,
        uint256 decimals,
        uint256 minTokens,
        uint256 maxTokens,
        uint256 usdPricePerToken
    ) public onlyRole(MINTER_ROLE) {
        minTokens = minTokens * (10 ** decimals);
        maxTokens = maxTokens * (10 ** decimals);
        amount = amount * (10 ** decimals);
        usdPricePerToken = (usdPricePerToken *
            (10 ** datafeedAddress.decimals()));

        // NFT
        _mint(treasury, id, 1, "");
        // ERC20
        _mint(treasury, id + 1, amount, "");

        // set token config
        tokenConfig[id] = TokenConfig(
            minTokens,
            maxTokens,
            usdPricePerToken,
            block.timestamp,
            block.timestamp + 1 weeks,
            treasury,
            decimals
        );
        emit mintRWA(
            treasury,
            id,
            amount,
            minTokens,
            maxTokens,
            usdPricePerToken,
            block.timestamp,
            block.timestamp + 1 weeks
        );
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function withdrawFunds(
        address _receiver
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint amount = getContractBalance();
        (bool sent, ) = _receiver.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

// Audacity admin -> 0x1C42aCcd92d491DB8b083Fa953B5E3D9A9E42aD5 deploy(
// deploy 1. 0x02657Bc72D9AFB778bf3edd14De1997cD46eF7a1,0x7b467A6962bE0ac80784F131049A25CDE27d62Fb
// mintrwa -> mints rwa to the treasury account
// 2. 1,10000,18,10,100,1
// From the Treasury, allow the erc20 tokens to be transferred
// 3. setapprovalforall 0x03A40474c1ac9f2456F5D0dde2266ec20B1D4e2f,true
// from the admin again from rwa contract, set the kyc for the user.
// 4.0x75Bc50a5664657c869Edc0E058d192EeEfD570eb,true
// Now the user can transfer the fund to the deposit method by selecting the projectid
// 5. Depositing from the user. deposit - setvalue to 20,1
/*

{
    "name": "Property 1",
    "description": "This is a sample property",
    "image": "",
    "model": "",
    "year": "2023",
    "attributes": [
        {
            "trait_type": "No of Properties",
            "value": "12"
        },
        {
            "trait_type": "Number of Rooms",
            "value": "4"
        },
        {
            "trait_type": "Area",
            "value": "5500 sq ft"
        },
        {
            "trait_type": "Project Duration",
            "value": 28
        },
        {
            "trait_type": "Structure",
            "value": "Duplex" // enum
        },
        {
            "trait_type": "Parking",
            "value": 3
        },
        {
            "trait_type": "Bath/toilet",
            "value": 5
        },
        {
            "trait_type": "HVAC",
            "value": "Central"
        },
        {
            "trait_type": "Street",
            "value": "Lagos"
        }
        {
            "trait_type": "City",
            "value": "Lagos"
        },
        {
            "trait_type": "Country",
            "value": "Lagos"
        },
        {
            "trait_type": "Developers",
            "value": "Paramount Realtors"
        }
    ]
},

*/

// forge install Bisonai/orakl --no-commit
