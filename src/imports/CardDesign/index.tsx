import imgImageWelcomeToHolisticBalancedSolutions from "./194809d69b0071642f3d7eb1e254206dc320ee8a.png";

function ImageWelcomeToHolisticBalancedSolutions() {
  return (
    <div className="h-[224px] relative shrink-0 w-full" data-name="Image (Welcome to Holistic Balanced Solutions)">
      <img alt="" className="absolute bg-clip-padding border-0 border-[transparent] border-solid inset-0 max-w-none object-cover pointer-events-none size-full" src={imgImageWelcomeToHolisticBalancedSolutions} />
    </div>
  );
}

function Container() {
  return (
    <div className="bg-[#f3f4f6] h-[224px] relative shrink-0 w-full" data-name="Container">
      <div className="bg-clip-padding border-0 border-[transparent] border-solid content-stretch flex flex-col items-start overflow-clip relative rounded-[inherit] size-full">
        <ImageWelcomeToHolisticBalancedSolutions />
      </div>
    </div>
  );
}

function Paragraph() {
  return (
    <div className="h-[79px] min-h-[48px] relative shrink-0 w-full" data-name="Paragraph">
      <div className="bg-clip-padding border-0 border-[transparent] border-solid content-stretch flex flex-col items-center min-h-[inherit] pb-[16px] relative size-full">
        <p className="[word-break:break-word] font-['Inter:Semi_Bold',sans-serif] font-semibold leading-[22px] not-italic relative shrink-0 text-[#1e2939] text-[16px] w-[292px]">Welcome to Holistic Balanced Solutions</p>
      </div>
    </div>
  );
}

function Button() {
  return (
    <div className="bg-[#f8fafc] h-[40px] relative rounded-[8px] shrink-0 w-[268px]" data-name="Button">
      <div aria-hidden className="absolute border border-[#5b5bd6] border-solid inset-0 pointer-events-none rounded-[8px]" />
      <div className="bg-clip-padding border-0 border-[transparent] border-solid relative size-full">
        <p className="-translate-x-1/2 [word-break:break-word] absolute font-['Inter:Semi_Bold',sans-serif] font-semibold leading-[16px] left-1/2 not-italic text-[#5b5bd6] text-[12px] text-center top-[calc(50%-8px)] whitespace-nowrap">View Course</p>
      </div>
    </div>
  );
}

function Container1() {
  return (
    <div className="h-[160px] relative shrink-0 w-full" data-name="Container">
      <div className="flex flex-col items-center size-full">
        <div className="bg-clip-padding border-0 border-[transparent] border-solid content-stretch flex flex-col items-center p-[16px] relative size-full">
          <Paragraph />
          <Button />
        </div>
      </div>
    </div>
  );
}

export default function CardDesign() {
  return (
    <div className="bg-white relative rounded-[14px] size-full" data-name="Card Design">
      <div className="content-stretch flex flex-col items-start overflow-clip p-px relative rounded-[inherit] size-full">
        <Container />
        <Container1 />
      </div>
      <div aria-hidden className="absolute border border-[#e5e7eb] border-solid inset-0 pointer-events-none rounded-[14px]" />
    </div>
  );
}