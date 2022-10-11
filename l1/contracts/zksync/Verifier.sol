// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "../common/libraries/UncheckedMath.sol";
import "./Plonk4VerifierWithAccessToDNext.sol";

contract Verifier is Plonk4VerifierWithAccessToDNext {
    using UncheckedMath for uint256;

    function get_verification_key() internal pure returns (VerificationKey memory vk) {
        vk.num_inputs = 1;
        vk.domain_size = 256;
        vk.omega = PairingsBn254.new_fr(0x1058a83d529be585820b96ff0a13f2dbd8675a9e5dd2336a6692cc1e5a526c81);
        // coefficients
        vk.gate_setup_commitments[0] = PairingsBn254.new_g1(
            0x05f5cabc4eab14cfabee1334ef7f33a66259cc9fd07af862308d5c41765adb4b,
            0x128a103fbe66c8ff697182c0963d963208b55a5a53ddeab9b4bc09dc2a68a9cc
        );
        vk.gate_setup_commitments[1] = PairingsBn254.new_g1(
            0x0d9980170c334c107e6ce4d66bbc4d23bbcdc97c020b1e1c3f6e04c6c663d2c2,
            0x0968205845091ceaf3f863b1613fbdf7ce9a87ccfd97f22011679e6350384419
        );
        vk.gate_setup_commitments[2] = PairingsBn254.new_g1(
            0x0c84a19b149a1612cb042ad86382b9e94367c0add60d07e12399999e7db09efe,
            0x1e02f70c44c9bfb7bf2164cee2ab4813bcb9be56eb432e2e9dfffffe196d846d
        );
        vk.gate_setup_commitments[3] = PairingsBn254.new_g1(
            0x1eb3599506a41a7d62e1f7438d6732fbb9d1eda7b9c7a0213eca63c9334ac5a9,
            0x23563d9f429908d8ea80bffa642840fb081936d45b388bafc504d9b1e5b1c410
        );
        vk.gate_setup_commitments[4] = PairingsBn254.new_g1(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000001
        );
        vk.gate_setup_commitments[5] = PairingsBn254.new_g1(
            0x063e8dac7ee3ee6a4569fd53b416fe17f8f10de8c435c336e5a1cf2e02643200,
            0x1d4c1781b78f926d55f89ef72abb96bee350ce60ddc684f5a02d87c5f4cdf943
        );
        vk.gate_setup_commitments[6] = PairingsBn254.new_g1(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000001
        );
        // gate selectors
        vk.gate_selectors_commitments[0] = PairingsBn254.new_g1(
            0x0b487eb34c8480ea506f5c6c25857155d61d7f9824b60bc80e1a415a5bcf247f,
            0x07ea0d0d0df9dbcc944e9341a5bb49ae796d9dc9d7ca1c032b53784715b946db
        );
        vk.gate_selectors_commitments[1] = PairingsBn254.new_g1(
            0x0fa66faa0b9ea782eb400175ac9f0c05f0de64332eec54a87cd20db4540baec2,
            0x07dea33d314c690c4bd4b21deda1a44b9f8dd87e539024622768c2f8b8bdabe1
        );
        // permutation
        vk.permutation_commitments[0] = PairingsBn254.new_g1(
            0x120482c52e31d2373f9b2dc80a47e68f035e278d220fa8a89d0c81f133343953,
            0x02928a78ea2e1a943e9220b7e288fd48a561263f8e5f94518f21aaa43781ceac
        );
        vk.permutation_commitments[1] = PairingsBn254.new_g1(
            0x1dfad2c4d60704bcf6af0abd9cce09151f063c4b52200c268e470c6a6c93cbca,
            0x08b28dd6ca14d7c33e078fe0f332a9a4d95ac8df171355de9e69930aec02b5dc
        );
        vk.permutation_commitments[2] = PairingsBn254.new_g1(
            0x0935a4fd6ab67925929661cf2d2e814f87f589ee6234cb9675ecc2d897f1b338,
            0x1032ccc41c047413fce4a847ba7e51e4a2ea406d89a88d480c5f0efaf6c8c89a
        );
        vk.permutation_commitments[3] = PairingsBn254.new_g1(
            0x0eafaea3af7d1fadb2138db1b991af5d2218f6892714fd019898c7e1a43ecfe8,
            0x28fb17eda285ed74cc9771d62fad22ab459bbb0a4968c489972aca8b7e618fcb
        );
        // lookup table commitments
        vk.lookup_selector_commitment = PairingsBn254.new_g1(
            0x155201a564e721b1f5c06315ad4e24eaad3cbdd6197b19cd903fe85613080f86,
            0x12fb201bc896572ac14357e2601f5118636f1eeb7b89c177ac940aac3b5253ec
        );
        vk.lookup_tables_commitments[0] = PairingsBn254.new_g1(
            0x1cb0e2ae4d52743898d94d7f1729bd0d3357ba035cdb6b3af7ebff9159f8f297,
            0x15ee595227c9e0f7a487ddb8072d5ea3cfd058bc569211c3546bc0e80051553f
        );
        vk.lookup_tables_commitments[1] = PairingsBn254.new_g1(
            0x13e4ab94c03a5a29719930c1361d854e244cf918f1e29cb031303f4a13b71977,
            0x0f792ef4c6c8746c97be61ed9b20f31ba2dec3bd5c91a2d9a4a586f19af3a07c
        );
        vk.lookup_tables_commitments[2] = PairingsBn254.new_g1(
            0x1c9e69bd2b04240ebe44fb23d67c596fce4a1336109fdce38c2f184a63cd8acc,
            0x1cbd3e72bdbce827227e503690b10be9365ae760e9d2babde5ba81edf12f8206
        );
        vk.lookup_tables_commitments[3] = PairingsBn254.new_g1(
            0x2a0d46339fbf72104df6a241b53a957602b1a16f6e3b9f89bf3e4c4645df823c,
            0x11a601d7b2eee4b7885f34c9873426ba1263f38eae2e0351d653b8b1ba9c67f6
        );
        vk.lookup_table_type_commitment = PairingsBn254.new_g1(
            0x1a70e43f18b18d686807c2b1c6471cd949dd251b48090bca443d86b97afae951,
            0x0e6e23ad15a1bd851b228788ae4a03bf25bda39ede6d5a92d501a8402a0dfe43
        );
        // non residues
        vk.non_residues[0] = PairingsBn254.new_fr(0x0000000000000000000000000000000000000000000000000000000000000005);
        vk.non_residues[1] = PairingsBn254.new_fr(0x0000000000000000000000000000000000000000000000000000000000000007);
        vk.non_residues[2] = PairingsBn254.new_fr(0x000000000000000000000000000000000000000000000000000000000000000a);

        // g2 elements
        vk.g2_elements[0] = PairingsBn254.new_g2(
            [
                0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2,
                0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed
            ],
            [
                0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b,
                0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa
            ]
        );
        vk.g2_elements[1] = PairingsBn254.new_g2(
            [
                0x260e01b251f6f1c7e7ff4e580791dee8ea51d87a358e038b4efe30fac09383c1,
                0x0118c4d5b837bcc2bc89b5b398b5974e9f5944073b32078b7e231fec938883b0
            ],
            [
                0x04fc6369f7110fe3d25156c1bb9a72859cf2a04641f99ba4ee413c80da6a5fe4,
                0x22febda3c0c0632a56475b4214e5615e11e6dd3f96e6cea2854a87d4dacc5e55
            ]
        );
    }

    function deserialize_proof(uint256[] calldata public_inputs, uint256[] calldata serialized_proof)
        internal
        pure
        returns (Proof memory proof)
    {
        // require(serialized_proof.length == 44); TODO
        proof.input_values = new uint256[](public_inputs.length);
        for (uint256 i = 0; i < public_inputs.length; i = i.uncheckedInc()) {
            proof.input_values[i] = public_inputs[i];
        }

        uint256 j;
        for (uint256 i = 0; i < STATE_WIDTH; i = i.uncheckedInc()) {
            proof.state_polys_commitments[i] = PairingsBn254.new_g1_checked(
                serialized_proof[j],
                serialized_proof[j.uncheckedInc()]
            );

            j = j.uncheckedAdd(2);
        }
        proof.copy_permutation_grand_product_commitment = PairingsBn254.new_g1_checked(
            serialized_proof[j],
            serialized_proof[j.uncheckedInc()]
        );
        j = j.uncheckedAdd(2);

        proof.lookup_s_poly_commitment = PairingsBn254.new_g1_checked(
            serialized_proof[j],
            serialized_proof[j.uncheckedInc()]
        );
        j = j.uncheckedAdd(2);

        proof.lookup_grand_product_commitment = PairingsBn254.new_g1_checked(
            serialized_proof[j],
            serialized_proof[j.uncheckedInc()]
        );
        j = j.uncheckedAdd(2);
        for (uint256 i = 0; i < proof.quotient_poly_parts_commitments.length; i = i.uncheckedInc()) {
            proof.quotient_poly_parts_commitments[i] = PairingsBn254.new_g1_checked(
                serialized_proof[j],
                serialized_proof[j.uncheckedInc()]
            );
            j = j.uncheckedAdd(2);
        }

        for (uint256 i = 0; i < proof.state_polys_openings_at_z.length; i = i.uncheckedInc()) {
            proof.state_polys_openings_at_z[i] = PairingsBn254.new_fr(serialized_proof[j]);

            j = j.uncheckedInc();
        }

        for (uint256 i = 0; i < proof.state_polys_openings_at_z_omega.length; i = i.uncheckedInc()) {
            proof.state_polys_openings_at_z_omega[i] = PairingsBn254.new_fr(serialized_proof[j]);

            j = j.uncheckedInc();
        }
        for (uint256 i = 0; i < proof.gate_selectors_openings_at_z.length; i = i.uncheckedInc()) {
            proof.gate_selectors_openings_at_z[i] = PairingsBn254.new_fr(serialized_proof[j]);

            j = j.uncheckedInc();
        }
        for (uint256 i = 0; i < proof.copy_permutation_polys_openings_at_z.length; i = i.uncheckedInc()) {
            proof.copy_permutation_polys_openings_at_z[i] = PairingsBn254.new_fr(serialized_proof[j]);

            j = j.uncheckedInc();
        }
        proof.copy_permutation_grand_product_opening_at_z_omega = PairingsBn254.new_fr(serialized_proof[j]);

        j = j.uncheckedInc();
        proof.lookup_s_poly_opening_at_z_omega = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.lookup_grand_product_opening_at_z_omega = PairingsBn254.new_fr(serialized_proof[j]);

        j = j.uncheckedInc();
        proof.lookup_t_poly_opening_at_z = PairingsBn254.new_fr(serialized_proof[j]);

        j = j.uncheckedInc();
        proof.lookup_t_poly_opening_at_z_omega = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.lookup_selector_poly_opening_at_z = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.lookup_table_type_poly_opening_at_z = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.quotient_poly_opening_at_z = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.linearization_poly_opening_at_z = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.opening_proof_at_z = PairingsBn254.new_g1_checked(
            serialized_proof[j],
            serialized_proof[j.uncheckedInc()]
        );
        j = j.uncheckedAdd(2);
        proof.opening_proof_at_z_omega = PairingsBn254.new_g1_checked(
            serialized_proof[j],
            serialized_proof[j.uncheckedInc()]
        );
    }

    function verify_serialized_proof(uint256[] calldata public_inputs, uint256[] calldata serialized_proof)
        public
        view
        returns (bool)
    {
        VerificationKey memory vk = get_verification_key();
        require(vk.num_inputs == public_inputs.length);

        Proof memory proof = deserialize_proof(public_inputs, serialized_proof);

        return verify(proof, vk);
    }
}
