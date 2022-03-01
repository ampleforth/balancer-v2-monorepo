// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../interfaces/IButtonWrapper.sol";
import "../interfaces/IAToken.sol";
import "../LinearPool.sol";

/**
 * @title UnbuttonAaveAmplLinearPool
 * @author @aalavandhan1984 (dev-support@fragments.org)
 * @notice This linear pool is between wAMPL (wrapped AMPL)
 *         and wAaveAMPL (wrapped aaveAMPL).
 * @dev The exchange rate between both is calculated based on:
 *        - the rate between wAMPL and AMPL
 *        - the rate between AMPL and aaveAMPL
 *        - the rate between wAaveAMPL and aaveAMPL
 *
 *      Both AMPL and aaveAMPL are rebasing assets and are wrapped into a non-rebasing version
 *      using the unbutton wrapper.
 *      https://github.com/buttonwood-protocol/button-wrappers/blob/main/contracts/UnbuttonToken.sol
 *      https://github.com/buttonwood-protocol/button-wrappers/blob/main/contracts/interfaces/IButtonWrapper.sol
 */
contract UnbuttonAaveAmplLinearPool is LinearPool {
    address private immutable _wAaveAMPL;

    constructor(
        IVault vault,
        string memory name,
        string memory symbol,
        IERC20 wAMPL,
        IERC20 wAaveAMPL,
        uint256 upperTarget,
        uint256 swapFeePercentage,
        uint256 pauseWindowDuration,
        uint256 bufferPeriodDuration,
        address owner
    )
        LinearPool(
            vault,
            name,
            symbol,
            wAMPL,     // main token
            wAaveAMPL, // wrapped token
            upperTarget,
            swapFeePercentage,
            pauseWindowDuration,
            bufferPeriodDuration,
            owner
        )
    {
        // NOTE: The linear pool's getWrappedToken() function is marked external
        // and thus the the reference to the wAaveAMPL token can't be queried
        // from methods in this subclass. Thus using a redundant storage variable
        // to store the reference.
        _wAaveAMPL = address(wAaveAMPL);
        
        address mainUnderlying = IButtonWrapper(address(wAMPL))
            .underlying();

        address wrappedUnderlying = 
            IAToken(IButtonWrapper(address(wAaveAMPL)).underlying())
            .UNDERLYING_ASSET_ADDRESS();

        _require(mainUnderlying == wrappedUnderlying, Errors.TOKENS_MISMATCH);
    }

    /*
     * @dev This function returns the exchange rate between the main token and
     *      the wrapped token as a 18 decimal fixed point number.
     *      In our case, its the exchange rate between wAMPL and wAaveAMPL.
     *      (i.e. The number of wAaveAMPL for each WAMPL)
     * ```
     */
    function _getWrappedTokenRate() internal view override returns (uint256) {
        // 1e18 wAMPL = r1 AMPL
        uint256 r1 = IButtonWrapper(getMainToken()).wrapperToUnderlying(10**18);

        // r1 AMPL =  r1 aAMPL (AMPL and aAMPL have a 1:1 exchange rate)

        // r1 aAMPL = r2 wAaveAMPL
        uint256 r2 = IButtonWrapper(_wAaveAMPL).underlyingToWrapper(r1);

        // 1e18 wAMPL = r2 wAaveAMPL
        return r2;
    }
}
