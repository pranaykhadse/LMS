import imgAcr28942341459202698019Copy2 from "./4a7a06bd8e8d6badb2c636d66020271ffe75b036.png";
import { imgAcr28942341459202698019Copy1 } from "./svg-38dsa";

function MaskGroup() {
  return (
    <div className="absolute contents left-0 top-0" data-name="Mask group">
      <div className="absolute h-[714px] left-0 mask-alpha mask-intersect mask-no-clip mask-no-repeat mask-position-[43px_226px] mask-size-[1392px_276px] top-0 w-[1509px]" style={{ maskImage: `url("${imgAcr28942341459202698019Copy1}")` }} data-name="Acr28942341459202698019 copy 1">
        <img alt="" className="absolute inset-0 max-w-none object-cover pointer-events-none size-full" src={imgAcr28942341459202698019Copy2} />
      </div>
    </div>
  );
}

function Container() {
  return <div className="absolute bg-gradient-to-r from-[#5865f2] from-[42.151%] h-[276px] left-0 opacity-80 rounded-[14px] to-[#7c3aed] top-0 w-[1392px]" data-name="Container" />;
}

function Frame() {
  return (
    <div className="content-stretch flex flex-col gap-[7px] items-start relative shrink-0 w-full">
      <p className="font-['Inter:Medium',sans-serif] font-medium leading-[36px] relative shrink-0 text-[22px] tracking-[-0.75px] w-full">Good Evening, Ayushi Gupta!</p>
      <p className="font-['Inter:Regular',sans-serif] font-normal leading-[22px] relative shrink-0 text-[16px] w-full">{`A leader is best when people barely know he exists...when his work is done, his aim fulfilled, they will all say: We did it ourselves."`}</p>
    </div>
  );
}

function Frame1() {
  return (
    <div className="[word-break:break-word] absolute content-stretch flex flex-col gap-[14px] items-start left-0 not-italic text-white top-0 w-[578px]">
      <Frame />
      <p className="font-['Inter:Medium',sans-serif] font-medium leading-[20px] relative shrink-0 text-[14px] tracking-[0.35px] w-full">- Lao-Tzu</p>
    </div>
  );
}

export default function Group() {
  return (
    <div className="contents relative size-full">
      <MaskGroup />
      <Container />
      <Frame1 />
    </div>
  );
}