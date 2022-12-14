module aptos_std::groth16 {
    #[test_only]
    use aptos_std::curves::{BLS12_381_G1, BLS12_381_G2, BLS12_381_Gt};
    use aptos_std::curves;

    struct VerifyingKey<phantom G1, phantom G2, phantom Gt> has drop {
        bytes: vector<u8>
    }

    struct Proof<phantom G1, phantom G2, phantom Gt> has drop {
        bytes: vector<u8>
    }

    native public fun verify_proof<G1,G2,Gt>(
        _verifying_key: &VerifyingKey<G1,G2,Gt>,
        _public_inputs: &vector<curves::Scalar<G1>>,
        _proof: &Proof<G1,G2,Gt>,
    ): bool;

    native public fun new_verifying_key_from_bytes<G1,G2,Gt>(bytes: &vector<u8>): VerifyingKey<G1,G2,Gt>;
    native public fun new_proof_from_bytes<G1,G2,Gt>(bytes: &vector<u8>): Proof<G1,G2,Gt>;

    #[test]
    fun t1() {
        let vk_bytes = x"09b2284943fa8e7a42b958e56a897507a11616c84be60258db0f470675355a3895e2145d736854f1263c85d60b4a1e4e05f538ee9b08d3254d25f3cfd8ca9526a471d84a49b9d27e65088e7308ae77686b4a1f02a856c2fd164a3361c17f642e030007829f78580e98f00bad92fc5649bc4a869e26ca48c403ccf040ebff656db8612b839241c028a5fc570004b2f15b02c03a0f78852619c9866e308b450394317d90219b072a432a40e2217f1cbd466028d983c0dbbf85c7762fae601e1c9c14fe1cc09c1bfd43e865e37e84f813b6b55fe2566587b8bac801ffe68b8de0a2c55889afc02304c0340e9f7f21bc0a2d0ffdfca9da4a4588e9001e7e4f530df990ea4ce10d7130bd568fefa3e1a01a6b0c4d8448f242a04b358f8e770023cf570f08fce0d37b82d271099befb00e1bb35be508d28da72797e22e732af7ff87f776ff7925aa0d524a2d5317ffef4d89630cf681e4eb278b2c9189fc8a47f4ef77d2ed3582255b5c4b3b1ebe1a8f0b02362ef0aa21dae7d955dea5d94fedc87105055df3f694e0fb5be9e48671c7c35991e1c460113b3862616c5e0cfad00e6918e3f2a153ea61e45ab7098d757832dde80703639a5be43c88f1e5d214b3a25d9fb71bc2f8a1216e91a3ddbe7bcf61b6aeea518760196389bc24341f65651cdb17160a7381b23cbfb5d42d3b22d182a63b33672def955b60130ce52130e6b2f01fc8892c70a74acc18f8c6add388db628f026b1d7385691423559e6cdc18637d81f2be09d7419effe5051341a6329207c80075f83a40caf99cdce6facee0a87f1c093f8464ab22da3e387358cfd7bc5d9d9c9e33e5ab87b52e26a3445d0b52ab1a781f0ac4a34038e7869cb5a4b42439e40c9b757c0c863c5c9cdee5e5d18ecd2716515ea28743d75594bb9f268f1ad877b2064d86b453833bd009ed4954e2846b05317965d3562d58ce22b1d611b85578f7d5af11ef40d0e962b84854a9e2064ce56e950fdac597a529870b454d9e585e00fc39745b9dcd2b3087ca397cb8e0672571e0307fb224858609d20524222403bbdff77d62ae764fc43dd62034b92742030265fd97d72cb16de7f5d0d8769d400c1567834c6032df7ef59013dc86246c8dfe8bcd12438d493feaa855ee57062517cdc68c6d0f02a00764d2f2a4351a504a0828c82728eecbf8f95d8178639456da0fbfc4fdb6869d0f8eff0503ec5dab0000000200c6068fc424ca5050d39b423903653eb3b5ff1db4d57fa33745933a4aca2bc0f6370d134874ecbe2c82c7465509a04511a91f5a0fee7b072f4b42ff7e3caee691b1d1ead64a79ab1644f33f5bab7e2a39c1334e7e6d64e668ffb0cfd09705f2087194b171173e33b6b638b84d3feb809d2374a7458a935669f4e3176fc11bd74853cf1a78b2f3f6669ace6fa319013e0ba1f6203018df324dcaad36e3fa261baf6ac04cc4db6d7cc532ac52fa04aae42dc57b7f0094524e087eeb7715ae2895";
        let vk = new_verifying_key_from_bytes<BLS12_381_G1,BLS12_381_G2,BLS12_381_Gt>(&vk_bytes);
        let public_bytes = x"6bf5eddf1a2bed5f168a1e5404e63535f7e660597646f18ac89b7234cd626e40";
        let public_1 = curves::scalar_from_bytes<BLS12_381_G1>(&public_bytes);
        let public_inputs = vector[public_1];
        let bytes = x"a1db77f5ccdc073523811fb48553e040137184bc571f06b43be02d510537e7dfe623c46faa7c6a7d0f36aed2ae3feb9eb8c74fa8e43960d031ed92f8930c105b45f80499d48dc85c586705fe564a45e7b8f0c5fb4400993dc5bc5d36cd5ecc770c4fa7f413c5acbd0e9215b3d6199d7392c8b8d02f80052ee88d6ddc9e8e5ebc5a0623906c3ce7c5c3537eae50b6b438a55b174c15887a1bde90082eabd8d944ba71ecfc3916a01a52e1cbee819c82e2f5bede228e21eff8c721dce7abc720ca";
        let proof = new_proof_from_bytes<BLS12_381_G1,BLS12_381_G2,BLS12_381_Gt>(&bytes);
        assert!(verify_proof(&vk, &public_inputs, &proof), 1);
    }
}